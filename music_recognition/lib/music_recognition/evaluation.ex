defmodule MusicRecognition.Evaluation do
  @moduledoc """
  Evaluation framework for measuring recognition accuracy.

  Iterates over songs in a database, picks random 5-15s samples from each,
  runs them through the recognition pipeline, and records the success rate.

  Works with both real audio files and synthetic tones.
  """

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database, Matcher}

  @doc """
  Evaluates recognition accuracy against a directory of audio files.

  For each song, takes `samples_per_song` random clips of 5-15s and tries
  to recognize them against the provided database.

  Returns an `%Evaluation.Result{}` struct with detailed stats.

  ## Options

    * `:samples_per_song` - Number of random samples per song (default: 3)
    * `:min_duration` - Minimum sample duration in seconds (default: 5)
    * `:max_duration` - Maximum sample duration in seconds (default: 15)
    * `:seed` - Random seed for reproducibility (default: 42)
  """
  def evaluate_directory(db, directory, opts \\ []) do
    samples_per_song = Keyword.get(opts, :samples_per_song, 3)
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)
    seed = Keyword.get(opts, :seed, 42)

    :rand.seed(:exsss, {seed, seed, seed})

    extensions = ~w(.mp3 .wav .flac .ogg .m4a .aac .wma)

    files =
      directory
      |> File.ls!()
      |> Enum.filter(fn f -> Path.extname(f) |> String.downcase() in extensions end)
      |> Enum.sort()

    trials =
      Enum.flat_map(files, fn file ->
        path = Path.join(directory, file)

        # Get the audio duration by reading the whole file
        case Audio.read_file(path) do
          {:ok, audio} ->
            total_seconds = Nx.size(audio) / Audio.sample_rate()

            for trial_idx <- 1..samples_per_song do
              duration = random_float(min_dur, min(max_dur, total_seconds))
              max_offset = max(0.0, total_seconds - duration)
              offset = if max_offset > 0, do: random_float(0.0, max_offset), else: 0.0

              IO.write("  #{file} [#{Float.round(offset, 1)}s + #{Float.round(duration, 1)}s]... ")

              result = run_trial(db, path, file, offset, duration, trial_idx)

              status = if result.correct?, do: "OK", else: "MISS"
              IO.puts("#{status}#{format_trial_detail(result)}")

              result
            end

          {:error, reason} ->
            IO.puts("  #{file}: SKIP (#{inspect(reason)})")
            []
        end
      end)

    build_result(trials, files)
  end

  @doc """
  Evaluates recognition accuracy using synthetic tones.

  Generates `num_songs` synthetic songs with random frequency combinations,
  builds a database, then tests recognition with random samples.

  This is useful for testing the pipeline without real audio files.

  ## Options

    * `:num_songs` - Number of synthetic songs to generate (default: 10)
    * `:song_duration` - Duration of each song in seconds (default: 30)
    * `:samples_per_song` - Random samples per song (default: 5)
    * `:min_duration` - Minimum sample duration (default: 5)
    * `:max_duration` - Maximum sample duration (default: 15)
    * `:seed` - Random seed (default: 42)
    * `:noise_level` - Amount of noise to add to samples, 0.0-1.0 (default: 0.0)
  """
  def evaluate_synthetic(opts \\ []) do
    num_songs = Keyword.get(opts, :num_songs, 10)
    song_duration = Keyword.get(opts, :song_duration, 30)
    samples_per_song = Keyword.get(opts, :samples_per_song, 5)
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)
    seed = Keyword.get(opts, :seed, 42)
    noise_level = Keyword.get(opts, :noise_level, 0.0)

    :rand.seed(:exsss, {seed, seed, seed})

    IO.puts("=== Synthetic Evaluation ===\n")
    IO.puts("Generating #{num_songs} synthetic songs (#{song_duration}s each)...\n")

    # Generate songs with distinct frequency combinations
    songs = generate_synthetic_songs(num_songs, song_duration)

    # Build the database
    IO.puts("Building fingerprint database...")

    db =
      Enum.reduce(songs, Database.new(), fn {name, audio, _freqs}, db ->
        {:ok, spec} = Spectrogram.compute(audio)
        peaks = Peaks.find_peaks(spec)
        fps = Fingerprint.generate(peaks)
        IO.puts("  #{name}: #{length(fps)} fingerprints")
        Database.insert(db, name, fps)
      end)

    IO.puts("\nDatabase: #{Database.size(db)} fingerprints, #{Database.num_songs(db)} songs\n")

    # Run evaluation
    IO.puts("Running recognition trials (#{samples_per_song} per song)...\n")

    trials =
      Enum.flat_map(songs, fn {name, full_audio, _freqs} ->
        total_seconds = Nx.size(full_audio) / Audio.sample_rate()

        for trial_idx <- 1..samples_per_song do
          duration = random_float(min_dur, min(max_dur, total_seconds))
          max_offset = max(0.0, total_seconds - duration)
          offset = if max_offset > 0, do: random_float(0.0, max_offset), else: 0.0

          # Extract sample from the full audio
          start_sample = trunc(offset * Audio.sample_rate())
          num_samples = trunc(duration * Audio.sample_rate())
          num_samples = min(num_samples, Nx.size(full_audio) - start_sample)

          sample = Nx.slice(full_audio, [start_sample], [num_samples])

          # Optionally add noise
          sample = if noise_level > 0, do: add_noise(sample, noise_level), else: sample

          IO.write("  #{name} [#{Float.round(offset, 1)}s + #{Float.round(duration, 1)}s]... ")

          {:ok, results} = Matcher.recognize_tensor(db, sample)

          trial = %{
            song_id: name,
            trial_number: trial_idx,
            offset: offset,
            duration: duration,
            results: results,
            correct?: results != [] and hd(results).song_id == name,
            top_match: if(results != [], do: hd(results), else: nil)
          }

          status = if trial.correct?, do: "OK", else: "MISS"
          IO.puts("#{status}#{format_trial_detail(trial)}")

          trial
        end
      end)

    song_names = Enum.map(songs, fn {name, _, _} -> name end)
    build_result(trials, song_names)
  end

  @doc """
  Prints a detailed report of evaluation results.
  """
  def print_report(result) do
    IO.puts("""

    ╔══════════════════════════════════════════╗
    ║       Recognition Evaluation Report      ║
    ╚══════════════════════════════════════════╝

    Overall Accuracy:  #{result.correct} / #{result.total} (#{format_pct(result.accuracy)})
    Songs Tested:      #{result.num_songs}
    Trials per Song:   #{if result.num_songs > 0, do: div(result.total, result.num_songs), else: 0}

    ── Per-Song Breakdown ──
    """)

    Enum.each(result.per_song, fn {song_id, stats} ->
      bar = accuracy_bar(stats.accuracy, 20)
      IO.puts("  #{String.pad_trailing(song_id, 30)} #{bar} #{format_pct(stats.accuracy)} (#{stats.correct}/#{stats.total})")
    end)

    if result.misses != [] do
      IO.puts("\n── Misidentifications ──\n")

      Enum.each(result.misses, fn trial ->
        matched = if trial.top_match, do: trial.top_match.song_id, else: "(none)"
        prob = if trial.top_match, do: " p=#{format_pct(trial.top_match.probability)}", else: ""
        IO.puts("  #{trial.song_id} → #{matched}#{prob} [#{Float.round(trial.offset, 1)}s + #{Float.round(trial.duration, 1)}s]")
      end)
    end

    if result.ambiguous != [] do
      IO.puts("\n── Ambiguous Matches (top 2 within 20% probability) ──\n")

      Enum.each(result.ambiguous, fn trial ->
        [first, second | _] = trial.results
        IO.puts("  #{trial.song_id}: #{first.song_id} (#{format_pct(first.probability)}) vs #{second.song_id} (#{format_pct(second.probability)})")
      end)
    end

    IO.puts("")
    result
  end

  # --- Private helpers ---

  defp run_trial(db, path, expected_song_id, offset, duration, trial_idx) do
    case Audio.read_file(path, offset: offset, duration: duration) do
      {:ok, audio} ->
        {:ok, results} = Matcher.recognize_tensor(db, audio)

        %{
          song_id: expected_song_id,
          trial_number: trial_idx,
          offset: offset,
          duration: duration,
          results: results,
          correct?: results != [] and hd(results).song_id == expected_song_id,
          top_match: if(results != [], do: hd(results), else: nil)
        }

      {:error, _reason} ->
        %{
          song_id: expected_song_id,
          trial_number: trial_idx,
          offset: offset,
          duration: duration,
          results: [],
          correct?: false,
          top_match: nil
        }
    end
  end

  defp build_result(trials, song_names) do
    total = length(trials)
    correct = Enum.count(trials, & &1.correct?)

    per_song =
      trials
      |> Enum.group_by(& &1.song_id)
      |> Enum.map(fn {song_id, song_trials} ->
        song_correct = Enum.count(song_trials, & &1.correct?)
        song_total = length(song_trials)

        {song_id, %{
          correct: song_correct,
          total: song_total,
          accuracy: if(song_total > 0, do: song_correct / song_total, else: 0.0)
        }}
      end)
      |> Enum.sort_by(fn {name, _} -> name end)

    misses = Enum.reject(trials, & &1.correct?)

    ambiguous =
      Enum.filter(trials, fn trial ->
        length(trial.results) >= 2 and
          Enum.at(trial.results, 1).probability > Enum.at(trial.results, 0).probability * 0.8
      end)

    %{
      total: total,
      correct: correct,
      accuracy: if(total > 0, do: correct / total, else: 0.0),
      num_songs: length(song_names),
      per_song: per_song,
      misses: misses,
      ambiguous: ambiguous,
      trials: trials
    }
  end

  defp generate_synthetic_songs(num_songs, duration) do
    # Generate distinct frequency combinations for each song.
    # Use base frequencies spread across the spectrum, with harmonics.
    base_freqs = [
      220.0, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00,
      493.88, 523.25, 587.33, 659.25, 698.46, 783.99, 880.00,
      987.77, 1046.50, 1174.66, 1318.51, 1396.91, 1567.98
    ]

    for i <- 0..(num_songs - 1) do
      # Pick 3 frequencies that are distinct for this song
      offset = rem(i * 3, length(base_freqs))
      freqs = Enum.slice(base_freqs ++ base_freqs, offset, 3)

      name = "song_#{String.pad_leading("#{i + 1}", 3, "0")}"
      audio = Audio.generate_composite_tone(freqs, duration)

      {name, audio, freqs}
    end
  end

  defp add_noise(tensor, level) do
    noise =
      Nx.Random.key(System.unique_integer([:positive]))
      |> Nx.Random.normal(shape: Nx.shape(tensor))
      |> elem(0)
      |> Nx.multiply(level)

    Nx.add(tensor, noise)
  end

  defp random_float(min, max) when max <= min, do: min
  defp random_float(min, max), do: min + :rand.uniform() * (max - min)

  defp format_pct(value), do: "#{Float.round(value * 100, 1)}%"

  defp format_trial_detail(%{top_match: nil}), do: " (no match)"

  defp format_trial_detail(%{top_match: match, results: results}) do
    base = " → #{match.song_id} (score: #{match.score}, p: #{format_pct(match.probability)})"

    if length(results) >= 2 do
      runner_up = Enum.at(results, 1)
      base <> " | runner-up: #{runner_up.song_id} (p: #{format_pct(runner_up.probability)})"
    else
      base
    end
  end

  defp accuracy_bar(accuracy, width) do
    filled = round(accuracy * width)
    empty = width - filled
    "[#{String.duplicate("#", filled)}#{String.duplicate("-", empty)}]"
  end
end
