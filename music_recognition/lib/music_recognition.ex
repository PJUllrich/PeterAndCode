defmodule MusicRecognition do
  @moduledoc """
  A Shazam-like audio fingerprinting and recognition system built with
  Nx and Explorer.

  Based on spectral fingerprinting (Wang 2003): audio is converted to a
  spectrogram via STFT, spectral peaks are paired into compact hashes,
  and matching uses time-aligned hash lookups in an Explorer DataFrame.

  ## Quick Start

      {db, _} = MusicRecognition.build_database("songs/")
      {:ok, results} = MusicRecognition.recognize(db, "sample.mp3")
      hd(results)
      #=> %{song_id: "bohemian_rhapsody.mp3", score: 142, confidence: 0.83, ...}
  """

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database}

  @audio_extensions ~w(.mp3 .wav .flac .ogg .m4a .aac .wma)

  @doc """
  Returns the supported audio file extensions.
  """
  def audio_extensions, do: @audio_extensions

  @doc """
  Lists audio files in a directory.
  """
  def list_audio_files(directory) do
    directory
    |> File.ls!()
    |> Enum.filter(&(Path.extname(&1) |> String.downcase() |> then(fn ext -> ext in @audio_extensions end)))
    |> Enum.sort()
  end

  @doc """
  Builds a fingerprint database from all audio files in a directory.

  Returns `{database, stats}`.
  """
  def build_database(directory) do
    files = list_audio_files(directory)

    Enum.reduce(files, {Database.new(), %{songs: 0, fingerprints: 0, errors: []}}, fn file, {db, stats} ->
      path = Path.join(directory, file)
      IO.write("Fingerprinting #{file}... ")

      case fingerprint_file(path) do
        {:ok, fps} ->
          IO.puts("#{length(fps)} fingerprints")

          {Database.insert(db, file, fps),
           %{stats | songs: stats.songs + 1, fingerprints: stats.fingerprints + length(fps)}}

        {:error, reason} ->
          IO.puts("ERROR: #{inspect(reason)}")
          {db, %{stats | errors: [{file, reason} | stats.errors]}}
      end
    end)
    |> tap(fn {_db, stats} ->
      IO.puts("\nDatabase built: #{stats.songs} songs, #{stats.fingerprints} fingerprints")
    end)
  end

  @doc """
  Fingerprints a single audio file. Returns `{:ok, fingerprints}` or `{:error, reason}`.
  """
  def fingerprint_file(path) do
    with {:ok, audio} <- Audio.read_file(path),
         {:ok, spectrogram} <- Spectrogram.compute(audio) do
      spectrogram |> Peaks.find_peaks() |> Fingerprint.generate() |> then(&{:ok, &1})
    end
  end

  @doc """
  Fingerprints a raw audio tensor. Returns `{:ok, fingerprints}` or `{:error, reason}`.
  """
  def fingerprint_tensor(audio) do
    with {:ok, spectrogram} <- Spectrogram.compute(audio) do
      spectrogram |> Peaks.find_peaks() |> Fingerprint.generate() |> then(&{:ok, &1})
    end
  end

  @doc """
  Recognizes a song from an audio file.

  ## Options

    * `:offset` - Start at this many seconds (default: 0)
    * `:duration` - Use this many seconds (default: 10)
    * `:top_n` - Max results to return (default: 5)
  """
  def recognize(db, file_path, opts \\ []) do
    audio_opts = Keyword.take(opts, [:offset, :duration])
    audio_opts = Keyword.put_new(audio_opts, :duration, 10)
    top_n = Keyword.get(opts, :top_n, 5)

    with {:ok, audio} <- Audio.read_file(file_path, audio_opts),
         {:ok, results} <- recognize_tensor(db, audio, top_n: top_n) do
      {:ok, results}
    end
  end

  @doc """
  Recognizes a song from a raw audio tensor.
  """
  def recognize_tensor(db, audio, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 5)

    with {:ok, fps} <- fingerprint_tensor(audio) do
      {:ok, db |> Database.query(fps) |> Enum.take(top_n)}
    end
  end

  @doc """
  Saves the fingerprint database to a Parquet file.
  """
  def save_database(db, path), do: Database.save(db, path)

  @doc """
  Loads a fingerprint database from a Parquet file.
  """
  def load_database(path), do: Database.load(path)

  @doc """
  Runs a full evaluation with synthetic songs and prints a report.

  ## Options

    * `:num_songs` - Number of synthetic songs (default: 10)
    * `:samples_per_song` - Random samples per song (default: 5)
    * `:noise_level` - Noise to add to samples, 0.0-1.0 (default: 0.0)
    * `:seed` - Random seed for reproducibility (default: 42)
  """
  def evaluate(opts \\ []) do
    MusicRecognition.Evaluation.evaluate_synthetic(opts)
    |> MusicRecognition.Evaluation.print_report()
  end

  @doc """
  Evaluates recognition accuracy against a directory of real audio files.
  """
  def evaluate_directory(db, directory, opts \\ []) do
    MusicRecognition.Evaluation.evaluate_directory(db, directory, opts)
    |> MusicRecognition.Evaluation.print_report()
  end

  @doc """
  Runs a single interactive demo: picks a random song, recognizes a
  random 5-15s clip, shows matches with timestamps and playback commands.

  Returns a result map for use with `play_sample/1` and `play_match/1`.
  """
  def demo(db, directory, opts \\ []) do
    MusicRecognition.Demo.run(db, directory, opts)
  end

  @doc "Plays the sample clip from a demo result."
  def play_sample(result), do: MusicRecognition.Demo.play_sample(result)

  @doc "Plays the matched song at the matched timestamp."
  def play_match(result), do: MusicRecognition.Demo.play_match(result)
end
