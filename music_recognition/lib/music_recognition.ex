defmodule MusicRecognition do
  @moduledoc """
  A Shazam-like audio fingerprinting and recognition system built with
  Nx and Explorer.

  ## How It Works

  The algorithm is based on spectral fingerprinting (Wang 2003):

  1. **Audio → Spectrogram**: Convert audio to a time-frequency representation
     using the Short-Time Fourier Transform (STFT).

  2. **Peak Detection**: Find the loudest frequencies in each time frame across
     multiple frequency bands.

  3. **Fingerprinting**: Pair nearby peaks into hashes that encode the frequencies
     of two peaks and their time difference. This creates signatures that are
     robust to noise and volume changes.

  4. **Matching**: Compare fingerprints from a sample against a database. A match
     is confirmed when many fingerprints align to the same time offset in a song.

  ## Quick Start

      # Build a database from audio files
      db = MusicRecognition.build_database("/path/to/songs/")

      # Recognize a sample
      {:ok, results} = MusicRecognition.recognize(db, "/path/to/sample.mp3")
      IO.inspect(hd(results))
      #=> %{song_id: "bohemian_rhapsody.mp3", score: 142, confidence: 0.83}

      # Save and load the database
      MusicRecognition.save_database(db, "fingerprints.parquet")
      db = MusicRecognition.load_database("fingerprints.parquet")
  """

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database, Matcher}

  @doc """
  Builds a fingerprint database from all audio files in a directory.

  Scans the directory for common audio formats (mp3, wav, flac, ogg, m4a)
  and fingerprints each file.

  Returns `{database, stats}` where stats is a map with processing details.
  """
  def build_database(directory) do
    extensions = ~w(.mp3 .wav .flac .ogg .m4a .aac .wma)

    files =
      directory
      |> File.ls!()
      |> Enum.filter(fn f ->
        ext = Path.extname(f) |> String.downcase()
        ext in extensions
      end)
      |> Enum.sort()

    {db, stats} =
      Enum.reduce(files, {Database.new(), %{songs: 0, fingerprints: 0, errors: []}}, fn file,
                                                                                        {db, stats} ->
        path = Path.join(directory, file)
        IO.write("Fingerprinting #{file}... ")

        case fingerprint_file(path) do
          {:ok, fingerprints} ->
            db = Database.insert(db, file, fingerprints)
            IO.puts("#{length(fingerprints)} fingerprints")

            {db,
             %{
               stats
               | songs: stats.songs + 1,
                 fingerprints: stats.fingerprints + length(fingerprints)
             }}

          {:error, reason} ->
            IO.puts("ERROR: #{inspect(reason)}")
            {db, %{stats | errors: [{file, reason} | stats.errors]}}
        end
      end)

    IO.puts("\nDatabase built: #{stats.songs} songs, #{stats.fingerprints} fingerprints")
    {db, stats}
  end

  @doc """
  Fingerprints a single audio file.

  Returns `{:ok, fingerprints}` or `{:error, reason}`.
  """
  def fingerprint_file(path) do
    with {:ok, audio} <- Audio.read_file(path),
         {:ok, spectrogram} <- Spectrogram.compute(audio) do
      peaks = Peaks.find_peaks(spectrogram)
      fingerprints = Fingerprint.generate(peaks)
      {:ok, fingerprints}
    end
  end

  @doc """
  Recognizes a song from an audio file or sample.

  ## Options

    * `:offset` - Start at this many seconds into the file (default: 0)
    * `:duration` - Use this many seconds for recognition (default: 10)
    * `:top_n` - Return at most this many results (default: 5)

  ## Example

      {:ok, results} = MusicRecognition.recognize(db, "sample.mp3", duration: 5)
      best = hd(results)
      IO.puts("Match: \#{best.song_id} (confidence: \#{Float.round(best.confidence * 100, 1)}%)")
  """
  def recognize(db, file_path, opts \\ []) do
    Matcher.recognize_file(db, file_path, opts)
  end

  @doc """
  Recognizes a song from a raw audio tensor (1D f32 tensor of PCM samples).
  """
  def recognize_tensor(db, audio_tensor, opts \\ []) do
    Matcher.recognize_tensor(db, audio_tensor, opts)
  end

  @doc """
  Saves the fingerprint database to a Parquet file.
  """
  def save_database(db, path) do
    Database.save(db, path)
  end

  @doc """
  Loads a fingerprint database from a Parquet file.
  """
  def load_database(path) do
    Database.load(path)
  end

  @doc """
  Prints a summary of the database contents.
  """
  def database_info(db) do
    IO.puts("""
    Fingerprint Database
    ====================
    Songs:        #{Database.num_songs(db)}
    Fingerprints: #{Database.size(db)}
    Song IDs:     #{Database.song_ids(db) |> Enum.join(", ")}
    """)
  end

  @doc """
  Runs a self-test using generated tones to verify the pipeline works.

  Creates 3 synthetic "songs" using composite tones, builds a database,
  then tries to recognize a segment from each song.
  """
  def self_test do
    IO.puts("=== MusicRecognition Self-Test ===\n")

    # Create 3 distinct "songs" using different frequency combinations
    songs = [
      {"song_a", [440.0, 880.0, 1320.0]},
      {"song_b", [523.25, 659.25, 783.99]},
      {"song_c", [349.23, 698.46, 1046.5]}
    ]

    # Generate 30 seconds of each song and build the database
    IO.puts("Building database from synthetic songs...")

    db =
      Enum.reduce(songs, Database.new(), fn {name, freqs}, db ->
        audio = Audio.generate_composite_tone(freqs, 30.0)
        {:ok, spectrogram} = Spectrogram.compute(audio)
        peaks = Peaks.find_peaks(spectrogram)
        fingerprints = Fingerprint.generate(peaks)
        IO.puts("  #{name}: #{length(peaks)} peaks, #{length(fingerprints)} fingerprints")
        Database.insert(db, name, fingerprints)
      end)

    IO.puts("\nDatabase: #{Database.size(db)} total fingerprints\n")

    # Try to recognize a 5-second segment from the middle of each song
    IO.puts("Recognition tests:")

    Enum.each(songs, fn {name, freqs} ->
      # Generate same song but take a 5-second slice from "the middle"
      # (since tones are stationary, any 5s works, but in real audio
      # the time offset matters)
      sample = Audio.generate_composite_tone(freqs, 5.0)
      {:ok, results} = Matcher.recognize_tensor(db, sample)

      if results != [] do
        best = hd(results)
        status = if best.song_id == name, do: "PASS", else: "FAIL"
        IO.puts("  [#{status}] Query #{name} → matched #{best.song_id} " <>
                 "(score: #{best.score}, confidence: #{Float.round(best.confidence * 100, 1)}%)")
      else
        IO.puts("  [FAIL] Query #{name} → no matches found")
      end
    end)

    IO.puts("\nSelf-test complete!")
  end

  @doc """
  Runs a full evaluation with synthetic songs and prints a report.

  Generates synthetic songs, builds a database, then tests recognition
  with random 5-15s samples. Prints a detailed accuracy report.

  ## Options

    * `:num_songs` - Number of synthetic songs (default: 10)
    * `:samples_per_song` - Random samples per song (default: 5)
    * `:noise_level` - Noise to add to samples, 0.0-1.0 (default: 0.0)
    * `:seed` - Random seed for reproducibility (default: 42)

  ## Example

      # Basic evaluation
      MusicRecognition.evaluate()

      # Stress test with noise
      MusicRecognition.evaluate(num_songs: 20, noise_level: 0.05)
  """
  def evaluate(opts \\ []) do
    Evaluation.evaluate_synthetic(opts) |> Evaluation.print_report()
  end

  @doc """
  Evaluates recognition accuracy against a directory of real audio files.

  Requires a pre-built database and the original audio directory.

  ## Example

      {db, _} = MusicRecognition.build_database("/path/to/songs/")
      MusicRecognition.evaluate_directory(db, "/path/to/songs/", samples_per_song: 5)
  """
  def evaluate_directory(db, directory, opts \\ []) do
    Evaluation.evaluate_directory(db, directory, opts) |> Evaluation.print_report()
  end
end
