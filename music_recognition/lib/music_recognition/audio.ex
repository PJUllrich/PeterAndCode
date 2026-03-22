defmodule MusicRecognition.Audio do
  @moduledoc """
  Reads audio files and converts them to raw PCM samples as Nx tensors.

  Uses ffmpeg to decode any audio format into mono 16-bit PCM at a fixed
  sample rate, then loads the raw bytes into an Nx tensor normalized to
  [-1.0, 1.0].
  """

  @sample_rate 11025

  def sample_rate, do: @sample_rate

  @doc """
  Reads an audio file and returns `{:ok, tensor}` with samples normalized
  to [-1.0, 1.0]. Accepts any format ffmpeg supports.

  ## Options

    * `:offset` - Start reading at this many seconds (default: 0)
    * `:duration` - Read only this many seconds (default: entire file)
  """
  def read_file(path, opts \\ []) do
    if File.exists?(path) do
      args =
        ["-i", path, "-ac", "1", "-ar", "#{@sample_rate}", "-f", "s16le"] ++
          build_args(opts) ++
          ["-v", "quiet", "pipe:1"]

      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {data, 0} -> {:ok, pcm_to_tensor(data)}
        {error, _} -> {:error, {:ffmpeg_failed, error}}
      end
    else
      {:error, :file_not_found}
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
  Generates a sine wave test tone as a 1D f32 tensor.
  """
  def generate_tone(frequency_hz, duration_seconds) do
    n = trunc(@sample_rate * duration_seconds)

    Nx.iota({n})
    |> Nx.divide(@sample_rate)
    |> Nx.multiply(2 * :math.pi() * frequency_hz)
    |> Nx.sin()
  end

  @doc """
  Generates a composite tone from multiple frequencies, normalized to [-1, 1].
  """
  def generate_composite_tone(frequencies, duration_seconds) do
    frequencies
    |> Enum.map(&generate_tone(&1, duration_seconds))
    |> Enum.reduce(&Nx.add/2)
    |> Nx.divide(length(frequencies))
  end

  defp build_args(opts) do
    offset_args(opts[:offset]) ++ duration_args(opts[:duration])
  end

  defp offset_args(nil), do: []
  defp offset_args(0), do: []
  defp offset_args(seconds), do: ["-ss", "#{seconds}"]

  defp duration_args(nil), do: []
  defp duration_args(seconds), do: ["-t", "#{seconds}"]

  defp pcm_to_tensor(binary) do
    for(<<sample::little-signed-16 <- binary>>, do: sample / 32768.0)
    |> Nx.tensor(type: :f32)
  end
end
