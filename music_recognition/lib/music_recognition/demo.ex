defmodule MusicRecognition.Demo do
  @moduledoc """
  Interactive demo that picks a random song, takes a random 5-15s sample,
  recognizes it, shows the matches with timestamps, and offers to play
  the audio using ffplay.
  """

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database, Matcher}

  @doc """
  Runs a single demo iteration against a directory of audio files.

  1. Picks a random song from the directory
  2. Takes a random 5-15s sample
  3. Recognizes it against the database
  4. Prints all matches with the timestamp where the sample aligns in each song
  5. Offers to play the sample and the matched song at the match point

  ## Options

    * `:seed` - Random seed (default: based on system time)
    * `:min_duration` - Minimum sample duration in seconds (default: 5)
    * `:max_duration` - Maximum sample duration in seconds (default: 15)
  """
  def run(db, directory, opts \\ []) do
    seed = Keyword.get(opts, :seed, System.system_time(:millisecond))
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)

    :rand.seed(:exsss, {seed, seed, seed})

    extensions = ~w(.mp3 .wav .flac .ogg .m4a .aac .wma)

    files =
      directory
      |> File.ls!()
      |> Enum.filter(fn f -> Path.extname(f) |> String.downcase() in extensions end)
      |> Enum.sort()

    if files == [] do
      IO.puts("No audio files found in #{directory}")
      :error
    else
      # Pick a random song
      source_file = Enum.random(files)
      source_path = Path.join(directory, source_file)

      run_with_file(db, directory, source_file, source_path, min_dur, max_dur)
    end
  end

  @doc """
  Runs a demo with a specific file as the source (instead of random).
  Useful for testing a specific song.
  """
  def run_with(db, directory, source_file, opts \\ []) do
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)
    seed = Keyword.get(opts, :seed, System.system_time(:millisecond))

    :rand.seed(:exsss, {seed, seed, seed})

    source_path = Path.join(directory, source_file)

    unless File.exists?(source_path) do
      IO.puts("File not found: #{source_path}")
      :error
    else
      run_with_file(db, directory, source_file, source_path, min_dur, max_dur)
    end
  end

  defp run_with_file(db, directory, source_file, source_path, min_dur, max_dur) do
    hop_size = Spectrogram.defaults().hop_size
    sample_rate = Audio.sample_rate()

    # Read the full file to determine duration
    case Audio.read_file(source_path) do
      {:ok, full_audio} ->
        total_seconds = Nx.size(full_audio) / sample_rate

        # Pick random duration and offset
        duration = random_float(min_dur, min(max_dur, total_seconds))
        max_offset = max(0.0, total_seconds - duration)
        offset = if max_offset > 0, do: random_float(0.0, max_offset), else: 0.0

        IO.puts("""

        ╔══════════════════════════════════════════╗
        ║          Music Recognition Demo          ║
        ╚══════════════════════════════════════════╝

        Source:   #{source_file}
        Sample:   #{format_time(offset)} - #{format_time(offset + duration)} (#{Float.round(duration, 1)}s)
        Song len: #{format_time(total_seconds)}
        """)

        # Read the sample
        case Audio.read_file(source_path, offset: offset, duration: duration) do
          {:ok, _sample_audio} ->
            IO.puts("Recognizing...\n")

            {:ok, results} = Matcher.recognize_file(db, source_path, offset: offset, duration: duration)

            if results == [] do
              IO.puts("No matches found.")
            else
              IO.puts("── Matches ──\n")
              IO.puts(String.pad_trailing("  #", 4) <>
                      String.pad_trailing("Song", 35) <>
                      String.pad_trailing("Score", 8) <>
                      String.pad_trailing("Prob", 8) <>
                      "Match Timestamp")
              IO.puts("  " <> String.duplicate("─", 75))

              Enum.with_index(results, 1)
              |> Enum.each(fn {match, idx} ->
                match_seconds = frame_to_seconds(match.match_offset, hop_size, sample_rate)
                is_correct = match.song_id == source_file
                marker = if is_correct, do: "*", else: " "

                IO.puts(
                  "  #{marker}#{idx}" <>
                  " " <> String.pad_trailing(truncate(match.song_id, 33), 35) <>
                  String.pad_trailing("#{match.score}", 8) <>
                  String.pad_trailing("#{Float.round(match.probability * 100, 1)}%", 8) <>
                  format_time(match_seconds)
                )
              end)

              IO.puts("\n  * = source song\n")

              # Build playback commands
              best = hd(results)
              best_match_seconds = frame_to_seconds(best.match_offset, hop_size, sample_rate)
              best_path = Path.join(directory, best.song_id)

              IO.puts("── Playback Commands ──\n")
              IO.puts("  Play the sample:")
              IO.puts("    ffplay -nodisp -autoexit -ss #{Float.round(offset, 1)} -t #{Float.round(duration, 1)} \"#{source_path}\"\n")

              IO.puts("  Play the best match at matched timestamp:")
              IO.puts("    ffplay -nodisp -autoexit -ss #{Float.round(best_match_seconds, 1)} -t #{Float.round(duration, 1)} \"#{best_path}\"\n")

              # Return structured result for programmatic use
              %{
                source: %{
                  file: source_file,
                  path: source_path,
                  offset: offset,
                  duration: duration
                },
                matches: Enum.map(results, fn match ->
                  Map.put(match, :match_seconds, frame_to_seconds(match.match_offset, hop_size, sample_rate))
                end),
                play: %{
                  sample: build_play_cmd(source_path, offset, duration),
                  match: build_play_cmd(best_path, best_match_seconds, duration)
                }
              }
            end

          {:error, reason} ->
            IO.puts("Failed to read sample: #{inspect(reason)}")
            :error
        end

      {:error, reason} ->
        IO.puts("Failed to read #{source_file}: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Plays audio using ffplay. Requires ffmpeg/ffplay to be installed.

  ## Options

    * `:offset` - Start at this many seconds (default: 0)
    * `:duration` - Play for this many seconds (default: nil = play to end)
  """
  def play(file_path, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    duration = Keyword.get(opts, :duration, nil)

    cmd = build_play_cmd(file_path, offset, duration)
    IO.puts("Playing: #{Path.basename(file_path)} at #{format_time(offset)}...")

    [program | args] = String.split(cmd)
    System.cmd(program, args, into: IO.stream(:stdio, :line))
    :ok
  end

  @doc """
  Plays the sample from a demo result.
  """
  def play_sample(%{play: %{sample: cmd}}) do
    IO.puts("Playing sample...")
    [program | args] = String.split(cmd)
    System.cmd(program, args, into: IO.stream(:stdio, :line))
    :ok
  end

  @doc """
  Plays the matched song at the matched timestamp from a demo result.
  """
  def play_match(%{play: %{match: cmd}}) do
    IO.puts("Playing match...")
    [program | args] = String.split(cmd)
    System.cmd(program, args, into: IO.stream(:stdio, :line))
    :ok
  end

  # --- Private helpers ---

  defp frame_to_seconds(frame_offset, hop_size, sample_rate) do
    # frame_offset can be negative (sample starts after song beginning)
    # or positive (sample aligns partway through the song)
    max(0.0, frame_offset * hop_size / sample_rate)
  end

  defp format_time(seconds) when is_float(seconds) do
    format_time(round(seconds * 10) / 10)
  end

  defp format_time(seconds) do
    total = trunc(seconds)
    mins = div(total, 60)
    secs = rem(total, 60)
    frac = Float.round(seconds - total, 1)
    fractional = if frac > 0, do: String.slice("#{frac}", 1..-1//1), else: ".0"
    "#{mins}:#{String.pad_leading("#{secs}", 2, "0")}#{fractional}"
  end

  defp truncate(string, max_len) do
    if String.length(string) > max_len do
      String.slice(string, 0, max_len - 2) <> ".."
    else
      string
    end
  end

  defp build_play_cmd(path, offset, nil) do
    "ffplay -nodisp -autoexit -ss #{Float.round(offset / 1, 1)} \"#{path}\""
  end

  defp build_play_cmd(path, offset, duration) do
    "ffplay -nodisp -autoexit -ss #{Float.round(offset / 1, 1)} -t #{Float.round(duration / 1, 1)} \"#{path}\""
  end

  defp random_float(min, max) when max <= min, do: min
  defp random_float(min, max), do: min + :rand.uniform() * (max - min)
end
