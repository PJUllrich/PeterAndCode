defmodule MusicRecognition.Demo do
  @moduledoc """
  Interactive demo that picks a random song, takes a random 5-15s sample,
  recognizes it, and shows matches with timestamps and playback commands.
  """

  alias MusicRecognition.{Audio, Spectrogram}

  @doc """
  Runs a single demo iteration against a directory of audio files.

  ## Options

    * `:seed` - Random seed (default: system time)
    * `:min_duration` - Minimum sample duration in seconds (default: 5)
    * `:max_duration` - Maximum sample duration in seconds (default: 15)
  """
  def run(db, directory, opts \\ []) do
    seed_rand(opts)

    case MusicRecognition.list_audio_files(directory) do
      [] ->
        IO.puts("No audio files found in #{directory}")
        :error

      files ->
        file = Enum.random(files)
        run_file(db, directory, file, opts)
    end
  end

  @doc """
  Runs a demo with a specific file as the source.
  """
  def run_with(db, directory, file, opts \\ []) do
    seed_rand(opts)
    path = Path.join(directory, file)

    if File.exists?(path) do
      run_file(db, directory, file, opts)
    else
      IO.puts("File not found: #{path}")
      :error
    end
  end

  @doc """
  Plays audio using ffplay.

  ## Options

    * `:offset` - Start at this many seconds (default: 0)
    * `:duration` - Play for this many seconds (default: entire file)
  """
  def play(file_path, opts \\ []) do
    IO.puts("Playing: #{Path.basename(file_path)} at #{format_time(opts[:offset] || 0)}...")
    run_ffplay(build_ffplay_args(file_path, opts[:offset] || 0, opts[:duration]))
  end

  @doc "Plays the sample clip from a demo result."
  def play_sample(%{source: source}) do
    IO.puts("Playing sample...")
    run_ffplay(build_ffplay_args(source.path, source.offset, source.duration))
  end

  @doc "Plays the matched song at the matched timestamp from a demo result."
  def play_match(%{best_match: match, source: source}) do
    IO.puts("Playing match...")
    run_ffplay(build_ffplay_args(match.path, match.match_seconds, source.duration))
  end

  # --- Core ---

  defp run_file(db, directory, file, opts) do
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)
    path = Path.join(directory, file)

    with {:ok, audio} <- Audio.read_file(path) do
      total_seconds = Nx.size(audio) / Audio.sample_rate()
      duration = random_float(min_dur, min(max_dur, total_seconds))
      offset = random_offset(total_seconds, duration)

      print_header(file, offset, duration, total_seconds)

      {:ok, results} = MusicRecognition.recognize(db, path, offset: offset, duration: duration)

      if results == [] do
        IO.puts("No matches found.")
        :no_match
      else
        print_matches(results, file, directory)
        print_playback_commands(path, offset, duration, hd(results), directory)
        build_demo_result(file, path, offset, duration, results, directory)
      end
    else
      {:error, reason} ->
        IO.puts("Failed to read #{file}: #{inspect(reason)}")
        :error
    end
  end

  # --- Output ---

  defp print_header(file, offset, duration, total) do
    IO.puts("""

    ╔══════════════════════════════════════════╗
    ║          Music Recognition Demo          ║
    ╚══════════════════════════════════════════╝

    Source:   #{file}
    Sample:   #{format_time(offset)} - #{format_time(offset + duration)} (#{Float.round(duration, 1)}s)
    Song len: #{format_time(total)}
    """)
    IO.puts("Recognizing...\n")
  end

  defp print_matches(results, source_file, directory) do
    hop = Spectrogram.defaults().hop_size
    sr = Audio.sample_rate()

    IO.puts("── Matches ──\n")
    IO.puts(pad("  #", 4) <> pad("Song", 35) <> pad("Score", 8) <> pad("Prob", 8) <> "Match Timestamp")
    IO.puts("  " <> String.duplicate("─", 75))

    results
    |> Enum.with_index(1)
    |> Enum.each(fn {match, idx} ->
      seconds = frame_to_seconds(match.match_offset, hop, sr)
      marker = if match.song_id == source_file, do: "*", else: " "

      IO.puts(
        "  #{marker}#{idx} " <>
          pad(truncate(match.song_id, 33), 35) <>
          pad("#{match.score}", 8) <>
          pad("#{Float.round(match.probability * 100, 1)}%", 8) <>
          format_time(seconds)
      )
    end)

    IO.puts("\n  * = source song\n")
  end

  defp print_playback_commands(source_path, offset, duration, best, directory) do
    best_seconds = frame_to_seconds(best.match_offset, Spectrogram.defaults().hop_size, Audio.sample_rate())
    best_path = Path.join(directory, best.song_id)

    IO.puts("── Playback Commands ──\n")
    IO.puts("  Play the sample:")
    IO.puts("    ffplay -nodisp -autoexit -ss #{Float.round(offset, 1)} -t #{Float.round(duration, 1)} \"#{source_path}\"\n")
    IO.puts("  Play the best match at matched timestamp:")
    IO.puts("    ffplay -nodisp -autoexit -ss #{Float.round(best_seconds, 1)} -t #{Float.round(duration, 1)} \"#{best_path}\"\n")
  end

  defp build_demo_result(file, path, offset, duration, results, directory) do
    hop = Spectrogram.defaults().hop_size
    sr = Audio.sample_rate()
    best = hd(results)
    best_seconds = frame_to_seconds(best.match_offset, hop, sr)

    %{
      source: %{file: file, path: path, offset: offset, duration: duration},
      matches: Enum.map(results, &Map.put(&1, :match_seconds, frame_to_seconds(&1.match_offset, hop, sr))),
      best_match: %{
        song_id: best.song_id,
        path: Path.join(directory, best.song_id),
        match_seconds: best_seconds
      }
    }
  end

  # --- Helpers ---

  defp seed_rand(opts) do
    seed = Keyword.get(opts, :seed, System.system_time(:millisecond))
    :rand.seed(:exsss, {seed, seed, seed})
  end

  defp random_offset(total, duration) do
    max_offset = max(0.0, total - duration)
    if max_offset > 0, do: random_float(0.0, max_offset), else: 0.0
  end

  defp random_float(min, max) when max <= min, do: min
  defp random_float(min, max), do: min + :rand.uniform() * (max - min)

  defp frame_to_seconds(offset, hop, sr), do: max(0.0, offset * hop / sr)

  defp format_time(seconds) do
    total = trunc(seconds)
    frac = seconds - total
    "#{div(total, 60)}:#{total |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}.#{trunc(frac * 10)}"
  end

  defp truncate(string, max_len) when byte_size(string) > max_len do
    String.slice(string, 0, max_len - 2) <> ".."
  end

  defp truncate(string, _), do: string

  defp pad(string, width), do: String.pad_trailing(string, width)

  defp build_ffplay_args(path, offset, nil) do
    ["-nodisp", "-autoexit", "-ss", "#{Float.round(offset / 1, 1)}", path]
  end

  defp build_ffplay_args(path, offset, duration) do
    ["-nodisp", "-autoexit", "-ss", "#{Float.round(offset / 1, 1)}", "-t", "#{Float.round(duration / 1, 1)}", path]
  end

  defp run_ffplay(args) do
    System.cmd("ffplay", args, into: IO.stream(:stdio, :line))
    :ok
  end
end
