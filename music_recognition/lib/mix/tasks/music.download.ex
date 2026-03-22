defmodule Mix.Tasks.Music.Download do
  @moduledoc """
  Downloads CC-licensed songs from the Jamendo API.

  ## Usage

      mix music.download
      mix music.download --count 50
      mix music.download --dir /path/to/songs
      mix music.download --tags rock,pop,jazz
      mix music.download --client-id your_client_id

  Songs are downloaded as MP3 with `artist - title.mp3` naming.
  A `songs.json` manifest is saved alongside the files. Downloads
  are resumable: existing files are skipped.
  """

  use Mix.Task

  @shortdoc "Downloads CC-licensed songs from Jamendo for music recognition"

  @api_base "https://api.jamendo.com/v3.0"
  @default_client_id "709fa152"
  @per_page 20

  @default_tags ~w(
    pop rock electronic hiphop jazz classical ambient folk blues reggae
    metal rnb latin country funk soul indie punk dance world
  )

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args, strict: [count: :integer, dir: :string, tags: :string, client_id: :string])

    count = opts[:count] || 100
    dir = opts[:dir] || "songs"
    client_id = opts[:client_id] || @default_client_id
    tags = if opts[:tags], do: opts[:tags] |> String.split(",") |> Enum.map(&String.trim/1), else: @default_tags

    File.mkdir_p!(dir)

    Mix.shell().info("""

    ╔══════════════════════════════════════════╗
    ║       Jamendo Music Downloader           ║
    ╚══════════════════════════════════════════╝

    Target:     #{count} songs
    Directory:  #{dir}/
    Tags:       #{Enum.join(tags, ", ")}
    """)

    existing = dir |> File.ls!() |> Enum.count(&String.ends_with?(&1, ".mp3"))
    if existing > 0, do: Mix.shell().info("Found #{existing} existing songs, will skip those.\n")

    Mix.shell().info("Fetching track list from Jamendo API...\n")
    tracks = fetch_tracks(client_id, tags, count)

    if tracks == [] do
      Mix.shell().error("Failed to fetch any tracks. Check your internet connection.")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(tracks)} tracks. Starting downloads...\n")

    {downloaded, skipped, errors} = download_all(tracks, dir)

    save_manifest(tracks, Path.join(dir, "songs.json"))

    Mix.shell().info("""

    ════════════════════════════════════════════
    Download complete!
    Downloaded: #{downloaded}
    Skipped:    #{skipped}
    Errors:     #{errors}
    Total:      #{downloaded + skipped} songs in #{dir}/
    ════════════════════════════════════════════

    Next steps:
      iex -S mix
      {db, _} = MusicRecognition.build_database("#{dir}")
      result = MusicRecognition.demo(db, "#{dir}")
    """)
  end

  # --- Fetching ---

  defp fetch_tracks(client_id, tags, count) do
    per_tag = max(1, div(count, length(tags)) + 1)

    tracks =
      tags
      |> Enum.flat_map(&fetch_page(client_id, %{"tags" => &1}, per_tag))
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(count)

    if length(tracks) < count do
      existing_ids = MapSet.new(tracks, & &1.id)

      extras =
        fetch_page(client_id, %{}, count - length(tracks) + 20)
        |> Enum.reject(&MapSet.member?(existing_ids, &1.id))
        |> Enum.take(count - length(tracks))

      tracks ++ extras
    else
      tracks
    end
  end

  defp fetch_page(client_id, extra_params, count) do
    pages = div(count - 1, @per_page) + 1

    Enum.flat_map(1..pages, fn page ->
      offset = (page - 1) * @per_page

      params =
        Map.merge(
          %{
            "client_id" => client_id,
            "format" => "json",
            "limit" => min(@per_page, count - offset),
            "offset" => offset,
            "order" => "popularity_total",
            "audioformat" => "mp3",
            "include" => "musicinfo+licenses"
          },
          extra_params
        )

      case Req.get("#{@api_base}/tracks/?#{URI.encode_query(params)}", retry: :transient, max_retries: 3) do
        {:ok, %{status: 200, body: %{"results" => results}}} ->
          Enum.map(results, &parse_track/1)

        {:ok, %{status: status}} ->
          Mix.shell().error("  Warning: API returned #{status} for #{inspect(extra_params)}")
          []

        {:error, reason} ->
          Mix.shell().error("  Warning: #{inspect(reason)}")
          []
      end
    end)
    |> Enum.take(count)
  end

  defp parse_track(track) do
    audio_url =
      if track["audiodownload_allowed"],
        do: track["audiodownload"] || track["audio"],
        else: track["audio"]

    %{
      id: track["id"],
      title: track["name"] || "Unknown",
      artist: track["artist_name"] || "Unknown",
      audio_url: audio_url,
      duration: track["duration"],
      license: track["license_ccurl"] || "CC",
      album: track["album_name"],
      tags: get_in(track, ["musicinfo", "tags", "genres"]) || []
    }
  end

  # --- Downloading ---

  defp download_all(tracks, dir) do
    total = length(tracks)

    tracks
    |> Enum.with_index(1)
    |> Enum.reduce({0, 0, 0}, fn {track, idx}, {dl, sk, err} ->
      filename = sanitize_filename(track.artist, track.title)
      filepath = Path.join(dir, filename)

      if File.exists?(filepath) do
        Mix.shell().info("  [#{idx}/#{total}] SKIP #{filename} (exists)")
        {dl, sk + 1, err}
      else
        Mix.shell().info("  [#{idx}/#{total}] Downloading #{filename}...")

        case download_file(track.audio_url, filepath) do
          :ok -> {dl + 1, sk, err}
          {:error, reason} ->
            Mix.shell().error("    ERROR: #{inspect(reason)}")
            {dl, sk, err + 1}
        end
      end
    end)
  end

  defp download_file(url, filepath) do
    case Req.get(url, into: File.stream!(filepath), retry: :transient, max_retries: 3) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        File.rm(filepath)
        {:error, {:http_status, status}}

      {:error, reason} ->
        File.rm(filepath)
        {:error, reason}
    end
  end

  # --- Helpers ---

  defp sanitize_filename(artist, title) do
    "#{artist} - #{title}"
    |> String.replace(~r/[<>:"\/\\|?*]/, "_")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 200)
    |> Kernel.<>(".mp3")
  end

  defp save_manifest(tracks, path) do
    manifest =
      Enum.map(tracks, fn t ->
        %{
          id: t.id,
          title: t.title,
          artist: t.artist,
          filename: sanitize_filename(t.artist, t.title),
          license: t.license,
          duration: t.duration,
          tags: t.tags
        }
      end)

    File.write!(path, Jason.encode!(manifest, pretty: true))
  end
end
