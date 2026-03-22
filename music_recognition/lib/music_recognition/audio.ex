defmodule MusicRecognition.Audio do
  @moduledoc """
  Reads audio files and converts them to raw PCM samples as Nx tensors.

  Uses ffmpeg to decode any audio format into mono 16-bit PCM at a fixed
  sample rate, then loads the raw bytes into an Nx tensor of f32 samples
  normalized to [-1.0, 1.0].
  """

  @sample_rate 11025
  @sample_format "s16le"

  @doc """
  Returns the sample rate used for all audio processing.
  """
  def sample_rate, do: @sample_rate

  @doc """
  Reads an audio file and returns `{:ok, tensor}` where tensor is a 1D f32
  tensor of samples normalized to [-1.0, 1.0].

  Accepts any format ffmpeg supports (mp3, wav, flac, ogg, etc.).

  ## Options

    * `:offset` - Start reading at this many seconds into the file (default: 0)
    * `:duration` - Read only this many seconds (default: read entire file)
  """
  def read_file(path, opts \\ []) do
    unless File.exists?(path) do
      {:error, :file_not_found}
    else
      offset = Keyword.get(opts, :offset, 0)
      duration = Keyword.get(opts, :duration, nil)

      args =
        ["-i", path, "-ac", "1", "-ar", "#{@sample_rate}", "-f", @sample_format] ++
          offset_args(offset) ++
          duration_args(duration) ++
          ["-v", "quiet", "pipe:1"]

      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {data, 0} ->
          tensor = pcm_to_tensor(data)
          {:ok, tensor}

        {error, _code} ->
          {:error, {:ffmpeg_failed, error}}
      end
    end
  end

  @doc """
  Like `read_file/2` but raises on error.
  """
  def read_file!(path, opts \\ []) do
    case read_file(path, opts) do
      {:ok, tensor} -> tensor
      {:error, reason} -> raise "Failed to read audio: #{inspect(reason)}"
    end
  end

  @doc """
  Generates a sine wave test tone as a 1D f32 tensor. Useful for testing.
  """
  def generate_tone(frequency_hz, duration_seconds) do
    num_samples = trunc(@sample_rate * duration_seconds)
    t = Nx.iota({num_samples}) |> Nx.divide(@sample_rate)
    Nx.multiply(2 * :math.pi() * frequency_hz, t) |> Nx.sin()
  end

  @doc """
  Generates a composite tone with multiple frequencies. Useful for testing
  with more realistic signals.
  """
  def generate_composite_tone(frequencies, duration_seconds) do
    tones = Enum.map(frequencies, &generate_tone(&1, duration_seconds))

    tones
    |> Enum.reduce(fn tone, acc -> Nx.add(acc, tone) end)
    |> then(fn t -> Nx.divide(t, length(frequencies)) end)
  end

  defp offset_args(0), do: []
  defp offset_args(seconds), do: ["-ss", "#{seconds}"]

  defp duration_args(nil), do: []
  defp duration_args(seconds), do: ["-t", "#{seconds}"]

  defp pcm_to_tensor(binary) do
    # s16le = signed 16-bit little-endian integers
    # Convert to list of integers, then to f32 tensor normalized to [-1, 1]
    samples =
      for <<sample::little-signed-integer-size(16) <- binary>> do
        sample / 32768.0
      end

    Nx.tensor(samples, type: :f32)
  end
end
