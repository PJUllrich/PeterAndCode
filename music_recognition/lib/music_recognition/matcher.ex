defmodule MusicRecognition.Matcher do
  @moduledoc """
  High-level matching interface that orchestrates the full recognition pipeline.

  Takes an audio sample (file path or tensor), runs it through the fingerprinting
  pipeline, and queries the database for matches.
  """

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database}

  @doc """
  Recognizes a song from an audio file.

  Returns `{:ok, results}` where results is a list of matches sorted by score,
  or `{:error, reason}`.

  ## Options

    * `:offset` - Start reading at this many seconds (default: 0)
    * `:duration` - Read only this many seconds (default: 10)
    * `:top_n` - Maximum number of results to return (default: 5)
  """
  def recognize_file(db, file_path, opts \\ []) do
    duration = Keyword.get(opts, :duration, 10)
    offset = Keyword.get(opts, :offset, 0)
    top_n = Keyword.get(opts, :top_n, 5)

    with {:ok, audio} <- Audio.read_file(file_path, offset: offset, duration: duration),
         {:ok, results} <- recognize_tensor(db, audio, top_n: top_n) do
      {:ok, results}
    end
  end

  @doc """
  Recognizes a song from a raw audio tensor.

  Returns `{:ok, results}` or `{:error, reason}`.
  """
  def recognize_tensor(db, audio_tensor, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 5)

    with {:ok, spectrogram} <- Spectrogram.compute(audio_tensor) do
      peaks = Peaks.find_peaks(spectrogram)
      fingerprints = Fingerprint.generate(peaks)
      results = Database.query(db, fingerprints) |> Enum.take(top_n)
      {:ok, results}
    end
  end
end
