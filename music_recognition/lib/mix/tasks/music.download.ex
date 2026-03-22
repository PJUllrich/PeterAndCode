defmodule Mix.Tasks.Music.Download do
  @moduledoc """
  Downloads CC-licensed songs from the Jamendo API for use with MusicRecognition.

  Jamendo is a platform for independent musicians who release music under
  Creative Commons licenses. The API is free to use with a client ID.

  ## Usage

      # Download 100 songs (default) into songs/ directory
      mix music.download

      # Download a specific number of songs
      mix music.download --count 50

      # Download into a custom directory
      mix music.download --dir /path/to/songs

      # Download specific genres (comma-separated)
      mix music.download --tags rock,pop,jazz

      # Use a custom Jamendo client ID
      mix music.download --client-id your_client_id

  ## Notes

  - Songs are downloaded as MP3 files at 96kbps (Jamendo's free streaming quality)
  - Each song is named as `artist - title.mp3`
  - A `songs.json` manifest is saved alongside the files with metadata
  - Downloads are resumable: existing files are skipped
  - Default client ID is a demo key; for heavy use, register at https://devportal.jamendo.com/
  """

  use Mix.Task

  @shortdoc "Downloads CC-licensed songs from Jamendo for music recognition"

  # Public demo client ID for Jamendo API (rate-limited but functional).
  # For heavy use, register your own at https://devportal.jamendo.com/
  @default_client_id "709fa152"
  @api_base "https://api.jamendo.com/v3.0"
  @default_dir "songs"
  @default_count 100
  @tracks_per_page 20

  # Popular tags to cycle through for variety
  @default_tags [
    "pop", "rock", "electronic", "hiphop", "jazz",
    "classical", "ambient", "folk", "blues", "reggae",
    "metal", "rnb", "latin", "country", "funk",
    "soul", "indie", "punk", "dance", "world"
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          count: :integer,
          dir: :string,
          tags: :string,
          client_id: :string
        ]
      )

    count = Keyword.get(opts, :count, @default_count)
    dir = Keyword.get(opts, :dir, @default_dir)
    client_id = Keyword.get(opts, :client_id, @default_client_id)

    tags =
      case Keyword.get(opts, :tags) do
        nil -> @default_tags
        tag_string -> String.split(tag_string, ",") |> Enum.map(&String.trim/1)
      end

    File.mkdir_p!(dir)

    Mix.shell().info("""

    ╔══════════════════════════════════════════╗
    ║       Jamendo Music Downloader           ║
    ╚══════════════════════════════════════════╝

    Target:     #{count} songs
    Directory:  #{dir}/
    Tags:       #{Enum.join(tags, ", ")}
    """)

    # Check for existing downloads
    existing = count_existing(dir)

    if existing > 0 do
      Mix.shell().info("Found #{existing} existing songs, will skip those.\n")
    end

    # Fetch track metadata from Jamendo API
    Mix.shell().info("Fetching track list from Jamendo API...\n")

    tracks = fetch_tracks(client_id, tags, count)

    if tracks == [] do
      Mix.shell().error("Failed to fetch any tracks from Jamendo. Check your internet connection.")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(tracks)} tracks. Starting downloads...\n")

    # Download each track
    {downloaded, skipped, errors} =
      tracks
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, 0}, fn {track, idx}, {dl, sk, err} ->
        filename = sanitize_filename(track.artist, track.title)
        filepath = Path.join(dir, filename)

        if File.exists?(filepath) do
          Mix.shell().info("  [#{idx}/#{length(tracks)}] SKIP #{filename} (exists)")
          {dl, sk + 1, err}
        else
          Mix.shell().info("  [#{idx}/#{length(tracks)}] Downloading #{filename}...")

          case download_file(track.audio_url, filepath) do
            :ok ->
              {dl + 1, sk, err}

            {:error, reason} ->
              Mix.shell().error("    ERROR: #{inspect(reason)}")
              {dl, sk, err + 1}
          end
        end
      end)

    # Save manifest
    manifest_path = Path.join(dir, "songs.json")
    save_manifest(tracks, manifest_path)

    Mix.shell().info("""

    ════════════════════════════════════════════
    Download complete!
    Downloaded: #{downloaded}
    Skipped:    #{skipped}
    Errors:     #{errors}
    Total:      #{downloaded + skipped} songs in #{dir}/
    Manifest:   #{manifest_path}
    ════════════════════════════════════════════

    Next steps:
      iex -S mix
      {db, _} = MusicRecognition.build_database("#{dir}")
      result = MusicRecognition.demo(db, "#{dir}")
    """)
  end

  defp fetch_tracks(client_id, tags, count) do
    # Distribute requests across tags for variety
    tracks_per_tag = max(1, div(count, length(tags)) + 1)

    tracks =
      tags
      |> Enum.flat_map(fn tag ->
        fetch_tag_tracks(client_id, tag, tracks_per_tag)
      end)
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(count)

    # If we didn't get enough from tags, do a popularity-based fetch
    if length(tracks) < count do
      remaining = count - length(tracks)
      existing_ids = MapSet.new(tracks, & &1.id)

      extras =
        fetch_popular_tracks(client_id, remaining + 20)
        |> Enum.reject(fn t -> MapSet.member?(existing_ids, t.id) end)
        |> Enum.take(remaining)

      tracks ++ extras
    else
      tracks
    end
  end

  defp fetch_tag_tracks(client_id, tag, count) do
    pages = div(count - 1, @tracks_per_page) + 1

    Enum.flat_map(1..pages, fn page ->
      offset = (page - 1) * @tracks_per_page
      limit = min(@tracks_per_page, count - offset)

      url =
        "#{@api_base}/tracks/?" <>
          URI.encode_query(%{
            "client_id" => client_id,
            "format" => "json",
            "limit" => limit,
            "offset" => offset,
            "tags" => tag,
            "order" => "popularity_total",
            "audioformat" => "mp3",
            "include" => "musicinfo+licenses"
          })

      case http_get_json(url) do
        {:ok, %{"results" => results}} ->
          Enum.map(results, &parse_track/1)

        {:error, reason} ->
          Mix.shell().error("  Warning: Failed to fetch #{tag} tracks (page #{page}): #{inspect(reason)}")
          []
      end
    end)
    |> Enum.take(count)
  end

  defp fetch_popular_tracks(client_id, count) do
    pages = div(count - 1, @tracks_per_page) + 1

    Enum.flat_map(1..pages, fn page ->
      offset = (page - 1) * @tracks_per_page
      limit = min(@tracks_per_page, count - offset)

      url =
        "#{@api_base}/tracks/?" <>
          URI.encode_query(%{
            "client_id" => client_id,
            "format" => "json",
            "limit" => limit,
            "offset" => offset,
            "order" => "popularity_total",
            "audioformat" => "mp3"
          })

      case http_get_json(url) do
        {:ok, %{"results" => results}} ->
          Enum.map(results, &parse_track/1)

        _ ->
          []
      end
    end)
    |> Enum.take(count)
  end

  defp parse_track(track) do
    # Prefer audiodownload (higher quality) over audio (low bitrate stream)
    audio_url =
      if track["audiodownload_allowed"] do
        track["audiodownload"] || track["audio"]
      else
        track["audio"]
      end

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

  defp http_get_json(url) do
    case Req.get(url, retry: :transient, max_retries: 3) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp download_file(url, filepath) do
    case Req.get(url, into: File.stream!(filepath), retry: :transient, max_retries: 3) do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        File.rm(filepath)
        {:error, {:http_status, status}}

      {:error, reason} ->
        File.rm(filepath)
        {:error, reason}
    end
  end

  defp sanitize_filename(artist, title) do
    name = "#{artist} - #{title}"

    name
    |> String.replace(~r/[<>:"\/\\|?*]/, "_")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 200)
    |> Kernel.<>(".mp3")
  end

  defp count_existing(dir) do
    case File.ls(dir) do
      {:ok, files} -> Enum.count(files, &String.ends_with?(&1, ".mp3"))
      _ -> 0
    end
  end

  defp save_manifest(tracks, path) do
    manifest =
      tracks
      |> Enum.map(fn t ->
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

    json = manifest |> Jason.encode!(pretty: true)
    File.write!(path, json)
  end
end
