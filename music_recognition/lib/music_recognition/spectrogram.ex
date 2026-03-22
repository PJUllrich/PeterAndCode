defmodule MusicRecognition.Spectrogram do
  @moduledoc """
  Computes Short-Time Fourier Transform (STFT) spectrograms from audio tensors.
  """

  @window_size 1024
  @hop_size 512

  @doc """
  Returns the default window and hop sizes.
  """
  def defaults, do: %{window_size: @window_size, hop_size: @hop_size}

  @doc """
  Computes an STFT spectrogram from a 1D audio tensor.

  Returns a 2D tensor of shape `{num_frames, num_frequency_bins}` with
  the magnitude spectrum at each time frame.

  ## Options

    * `:window_size` - FFT window size in samples (default: #{@window_size})
    * `:hop_size` - Hop between consecutive windows (default: #{@hop_size})
  """
  def compute(audio, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, @window_size)
    hop_size = Keyword.get(opts, :hop_size, @hop_size)
    num_frames = div(Nx.size(audio) - window_size, hop_size) + 1
    freq_bins = div(window_size, 2) + 1

    if num_frames <= 0 do
      {:error, :audio_too_short}
    else
      window = hann_window(window_size)

      frames =
        for i <- 0..(num_frames - 1) do
          audio
          |> Nx.slice([i * hop_size], [window_size])
          |> Nx.multiply(window)
          |> Nx.fft(length: window_size)
          |> magnitude()
          |> Nx.slice([0], [freq_bins])
        end

      {:ok, Nx.stack(frames)}
    end
  end

  @doc """
  Like `compute/2` but raises on error.
  """
  def compute!(audio, opts \\ []) do
    case compute(audio, opts) do
      {:ok, spectrogram} -> spectrogram
      {:error, reason} -> raise "Failed to compute spectrogram: #{inspect(reason)}"
    end
  end

  @doc """
  Converts a frame index to a time in seconds.
  """
  def frame_to_seconds(frame_index, hop_size \\ @hop_size, sample_rate \\ MusicRecognition.Audio.sample_rate()) do
    frame_index * hop_size / sample_rate
  end

  # Hann window: 0.5 * (1 - cos(2*pi*n / (N-1)))
  defp hann_window(size) do
    scale = 2 * :math.pi() / (size - 1)

    Nx.iota({size})
    |> Nx.as_type(:f32)
    |> Nx.multiply(scale)
    |> Nx.cos()
    |> Nx.negate()
    |> Nx.add(1)
    |> Nx.multiply(0.5)
  end

  defp magnitude(complex) do
    real = Nx.real(complex)
    imag = Nx.imag(complex)
    Nx.add(Nx.pow(real, 2), Nx.pow(imag, 2)) |> Nx.sqrt()
  end
end
