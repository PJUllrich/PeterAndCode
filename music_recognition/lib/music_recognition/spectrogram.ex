defmodule MusicRecognition.Spectrogram do
  @moduledoc """
  Computes Short-Time Fourier Transform (STFT) spectrograms from audio tensors.

  The STFT works by sliding a window across the audio signal, applying a
  Hann window function to each chunk, computing the FFT, and taking the
  magnitude of the result. This gives us a 2D time-frequency representation.
  """

  import Nx.Defn

  # Window size in samples. 1024 at 11025 Hz ≈ 93ms per frame.
  # This gives us ~5.4 Hz frequency resolution.
  @default_window_size 1024

  # Hop size = window / 2 for 50% overlap. This means ~10.7 frames per second.
  @default_hop_size 512

  @doc """
  Computes an STFT spectrogram from a 1D audio tensor.

  Returns a 2D tensor of shape `{num_frames, num_frequency_bins}` containing
  the magnitude spectrum at each time frame.

  ## Options

    * `:window_size` - FFT window size in samples (default: #{@default_window_size})
    * `:hop_size` - Hop between consecutive windows (default: #{@default_hop_size})
  """
  def compute(audio_tensor, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, @default_window_size)
    hop_size = Keyword.get(opts, :hop_size, @default_hop_size)

    num_samples = Nx.size(audio_tensor)
    num_frames = div(num_samples - window_size, hop_size) + 1

    if num_frames <= 0 do
      {:error, :audio_too_short}
    else
      window = hann_window(window_size)

      frames =
        for i <- 0..(num_frames - 1) do
          start = i * hop_size

          audio_tensor
          |> Nx.slice([start], [window_size])
          |> Nx.multiply(window)
          |> Nx.fft(length: window_size)
          |> magnitude()
          # Only keep positive frequencies (first half + 1 of FFT output)
          |> Nx.slice([0], [div(window_size, 2) + 1])
        end

      {:ok, Nx.stack(frames)}
    end
  end

  @doc """
  Like `compute/2` but raises on error.
  """
  def compute!(audio_tensor, opts \\ []) do
    case compute(audio_tensor, opts) do
      {:ok, spectrogram} -> spectrogram
      {:error, reason} -> raise "Failed to compute spectrogram: #{inspect(reason)}"
    end
  end

  @doc """
  Converts a frequency bin index to a frequency in Hz.
  """
  def bin_to_frequency(bin_index, sample_rate, window_size) do
    bin_index * sample_rate / window_size
  end

  @doc """
  Converts a frame index to a time in seconds.
  """
  def frame_to_time(frame_index, hop_size, sample_rate) do
    frame_index * hop_size / sample_rate
  end

  @doc """
  Returns the default window and hop sizes.
  """
  def defaults do
    %{window_size: @default_window_size, hop_size: @default_hop_size}
  end

  # Hann window: 0.5 * (1 - cos(2π*n / (N-1)))
  # Reduces spectral leakage by tapering the edges of each frame to zero.
  defp hann_window(size) do
    n = Nx.iota({size}) |> Nx.as_type(:f32)
    scale = 2 * :math.pi() / (size - 1)
    Nx.multiply(scale, n) |> Nx.cos() |> Nx.negate() |> Nx.add(1) |> Nx.multiply(0.5)
  end

  # Magnitude of complex FFT output: sqrt(real² + imag²)
  defp magnitude(complex_tensor) do
    real = Nx.real(complex_tensor)
    imag = Nx.imag(complex_tensor)

    Nx.add(Nx.pow(real, 2), Nx.pow(imag, 2))
    |> Nx.sqrt()
  end
end
