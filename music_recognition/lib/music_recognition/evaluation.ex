defmodule MusicRecognition.Evaluation do
  @moduledoc """
  Evaluation framework for measuring recognition accuracy.

  Tests recognition with random 5-15s samples and records success rate.
  Works with both real audio files and synthetic tones.
  """

  alias MusicRecognition.{Audio, Database}

  @base_frequencies [
    220.0, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00,
    493.88, 523.25, 587.33, 659.25, 698.46, 783.99, 880.00,
    987.77, 1046.50, 1174.66, 1318.51, 1396.91, 1567.98
  ]

  @doc """
  Evaluates recognition accuracy against a directory of audio files.

  ## Options

    * `:samples_per_song` - Random samples per song (default: 3)
    * `:min_duration` - Minimum sample duration in seconds (default: 5)
    * `:max_duration` - Maximum sample duration in seconds (default: 15)
    * `:seed` - Random seed for reproducibility (default: 42)
  """
  def evaluate_directory(db, directory, opts \\ []) do
    seed_rand(opts)
    samples_per_song = Keyword.get(opts, :samples_per_song, 3)
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)

    files = MusicRecognition.list_audio_files(directory)

    trials =
      Enum.flat_map(files, fn file ->
        path = Path.join(directory, file)

        case Audio.read_file(path) do
          {:ok, audio} ->
            total = Nx.size(audio) / Audio.sample_rate()

            for _ <- 1..samples_per_song do
              {offset, duration} = random_clip(total, min_dur, max_dur)
              IO.write("  #{file} [#{r(offset)}s + #{r(duration)}s]... ")

              trial = run_file_trial(db, path, file, offset, duration)
              print_trial(trial)
              trial
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

  ## Options

    * `:num_songs` - Number of synthetic songs (default: 10)
    * `:song_duration` - Duration of each song in seconds (default: 30)
    * `:samples_per_song` - Random samples per song (default: 5)
    * `:min_duration` / `:max_duration` - Sample duration range (default: 5-15)
    * `:seed` - Random seed (default: 42)
    * `:noise_level` - Noise to add to samples, 0.0-1.0 (default: 0.0)
  """
  def evaluate_synthetic(opts \\ []) do
    seed_rand(opts)
    num_songs = Keyword.get(opts, :num_songs, 10)
    song_duration = Keyword.get(opts, :song_duration, 30)
    samples_per_song = Keyword.get(opts, :samples_per_song, 5)
    min_dur = Keyword.get(opts, :min_duration, 5)
    max_dur = Keyword.get(opts, :max_duration, 15)
    noise_level = Keyword.get(opts, :noise_level, 0.0)

    IO.puts("=== Synthetic Evaluation ===\n")
    IO.puts("Generating #{num_songs} synthetic songs (#{song_duration}s each)...\n")

    songs = generate_songs(num_songs, song_duration)

    IO.puts("Building fingerprint database...")

    db =
      Enum.reduce(songs, Database.new(), fn {name, audio, _freqs}, db ->
        {:ok, fps} = MusicRecognition.fingerprint_tensor(audio)
        IO.puts("  #{name}: #{length(fps)} fingerprints")
        Database.insert(db, name, fps)
      end)

    IO.puts("\nDatabase: #{Database.size(db)} fingerprints, #{Database.num_songs(db)} songs\n")
    IO.puts("Running recognition trials (#{samples_per_song} per song)...\n")

    trials =
      Enum.flat_map(songs, fn {name, full_audio, _freqs} ->
        total = Nx.size(full_audio) / Audio.sample_rate()

        for _ <- 1..samples_per_song do
          {offset, duration} = random_clip(total, min_dur, max_dur)
          sample = slice_audio(full_audio, offset, duration)
          sample = maybe_add_noise(sample, noise_level)

          IO.write("  #{name} [#{r(offset)}s + #{r(duration)}s]... ")

          trial = run_tensor_trial(db, sample, name, offset, duration)
          print_trial(trial)
          trial
        end
      end)

    song_names = Enum.map(songs, &elem(&1, 0))
    build_result(trials, song_names)
  end

  @doc """
  Prints a detailed report of evaluation results.
  """
  def print_report(result) do
    trials_per = if result.num_songs > 0, do: div(result.total, result.num_songs), else: 0

    IO.puts("""

    ╔══════════════════════════════════════════╗
    ║       Recognition Evaluation Report      ║
    ╚══════════════════════════════════════════╝

    Overall Accuracy:  #{result.correct} / #{result.total} (#{pct(result.accuracy)})
    Songs Tested:      #{result.num_songs}
    Trials per Song:   #{trials_per}

    ── Per-Song Breakdown ──
    """)

    Enum.each(result.per_song, fn {song_id, stats} ->
      bar = accuracy_bar(stats.accuracy, 20)
      IO.puts("  #{String.pad_trailing(song_id, 30)} #{bar} #{pct(stats.accuracy)} (#{stats.correct}/#{stats.total})")
    end)

    if result.misses != [] do
      IO.puts("\n── Misidentifications ──\n")

      Enum.each(result.misses, fn trial ->
        matched = if trial.top_match, do: trial.top_match.song_id, else: "(none)"
        prob = if trial.top_match, do: " p=#{pct(trial.top_match.probability)}", else: ""
        IO.puts("  #{trial.song_id} -> #{matched}#{prob} [#{r(trial.offset)}s + #{r(trial.duration)}s]")
      end)
    end

    if result.ambiguous != [] do
      IO.puts("\n── Ambiguous Matches (top 2 within 20% probability) ──\n")

      Enum.each(result.ambiguous, fn trial ->
        [first, second | _] = trial.results
        IO.puts("  #{trial.song_id}: #{first.song_id} (#{pct(first.probability)}) vs #{second.song_id} (#{pct(second.probability)})")
      end)
    end

    IO.puts("")
    result
  end

  # --- Trials ---

  defp run_file_trial(db, path, song_id, offset, duration) do
    case Audio.read_file(path, offset: offset, duration: duration) do
      {:ok, audio} -> run_tensor_trial(db, audio, song_id, offset, duration)
      {:error, _} -> build_trial(song_id, offset, duration, [])
    end
  end

  defp run_tensor_trial(db, audio, song_id, offset, duration) do
    {:ok, results} = MusicRecognition.recognize_tensor(db, audio)
    build_trial(song_id, offset, duration, results)
  end

  defp build_trial(song_id, offset, duration, results) do
    %{
      song_id: song_id,
      offset: offset,
      duration: duration,
      results: results,
      correct?: results != [] and hd(results).song_id == song_id,
      top_match: List.first(results)
    }
  end

  defp print_trial(trial) do
    status = if trial.correct?, do: "OK", else: "MISS"
    IO.puts("#{status}#{format_trial_detail(trial)}")
  end

  defp format_trial_detail(%{top_match: nil}), do: " (no match)"

  defp format_trial_detail(%{top_match: match, results: results}) do
    base = " -> #{match.song_id} (score: #{match.score}, p: #{pct(match.probability)})"

    case results do
      [_, runner_up | _] -> base <> " | runner-up: #{runner_up.song_id} (p: #{pct(runner_up.probability)})"
      _ -> base
    end
  end

  # --- Result building ---

  defp build_result(trials, song_names) do
    total = length(trials)
    correct = Enum.count(trials, & &1.correct?)

    per_song =
      trials
      |> Enum.group_by(& &1.song_id)
      |> Enum.map(fn {song_id, song_trials} ->
        n = length(song_trials)
        c = Enum.count(song_trials, & &1.correct?)
        {song_id, %{correct: c, total: n, accuracy: if(n > 0, do: c / n, else: 0.0)}}
      end)
      |> Enum.sort_by(&elem(&1, 0))

    ambiguous =
      Enum.filter(trials, fn trial ->
        match?([first, second | _], trial.results) and
          Enum.at(trial.results, 1).probability > Enum.at(trial.results, 0).probability * 0.8
      end)

    %{
      total: total,
      correct: correct,
      accuracy: if(total > 0, do: correct / total, else: 0.0),
      num_songs: length(song_names),
      per_song: per_song,
      misses: Enum.reject(trials, & &1.correct?),
      ambiguous: ambiguous,
      trials: trials
    }
  end

  # --- Audio helpers ---

  defp random_clip(total_seconds, min_dur, max_dur) do
    duration = random_float(min_dur, min(max_dur, total_seconds))
    max_offset = max(0.0, total_seconds - duration)
    offset = if max_offset > 0, do: random_float(0.0, max_offset), else: 0.0
    {offset, duration}
  end

  defp slice_audio(audio, offset, duration) do
    sr = Audio.sample_rate()
    start = trunc(offset * sr)
    len = min(trunc(duration * sr), Nx.size(audio) - start)
    Nx.slice(audio, [start], [len])
  end

  defp maybe_add_noise(sample, level) when level <= 0, do: sample

  defp maybe_add_noise(sample, level) do
    {noise, _} =
      System.unique_integer([:positive])
      |> Nx.Random.key()
      |> Nx.Random.normal(shape: Nx.shape(sample))

    Nx.add(sample, Nx.multiply(noise, level))
  end

  defp generate_songs(num_songs, duration) do
    freqs = @base_frequencies

    for i <- 0..(num_songs - 1) do
      offset = rem(i * 3, length(freqs))
      song_freqs = Enum.slice(freqs ++ freqs, offset, 3)
      name = "song_#{String.pad_leading("#{i + 1}", 3, "0")}"
      {name, Audio.generate_composite_tone(song_freqs, duration), song_freqs}
    end
  end

  # --- Formatting ---

  defp seed_rand(opts) do
    seed = Keyword.get(opts, :seed, 42)
    :rand.seed(:exsss, {seed, seed, seed})
  end

  defp random_float(min, max) when max <= min, do: min
  defp random_float(min, max), do: min + :rand.uniform() * (max - min)

  defp r(val), do: Float.round(val, 1)
  defp pct(val), do: "#{Float.round(val * 100, 1)}%"

  defp accuracy_bar(accuracy, width) do
    filled = round(accuracy * width)
    "[#{String.duplicate("#", filled)}#{String.duplicate("-", width - filled)}]"
  end
end
