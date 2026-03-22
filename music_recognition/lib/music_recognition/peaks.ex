defmodule MusicRecognition.Peaks do
  @moduledoc """
  Detects spectral peaks in a spectrogram.

  Peaks are points in the time-frequency plane that are louder than their
  neighbors. These become the anchor points for fingerprint generation.

  We use a band-based approach: divide the frequency range into bands and
  pick the loudest frequency in each band per time frame. This ensures we
  capture both bass and treble content.
  """

  # Frequency bands (in bin indices for a 1024-point FFT at 11025 Hz).
  # Each bin ≈ 5.4 Hz, so:
  #   Band 0:    0 -  10 →    0 -   54 Hz (sub-bass)
  #   Band 1:   10 -  20 →   54 -  108 Hz (bass)
  #   Band 2:   20 -  40 →  108 -  216 Hz (low-mid)
  #   Band 3:   40 -  80 →  216 -  432 Hz (mid)
  #   Band 4:   80 - 160 →  432 -  864 Hz (upper-mid)
  #   Band 5:  160 - 512 →  864 - 2756 Hz (treble)
  @frequency_bands [
    {0, 10},
    {10, 20},
    {20, 40},
    {40, 80},
    {80, 160},
    {160, 512}
  ]

  # Minimum magnitude threshold to consider a peak (filters out silence/noise)
  @min_magnitude 1.0e-3

  @doc """
  Finds spectral peaks in a spectrogram.

  Returns a list of `{frame_index, frequency_bin}` tuples, sorted by frame index.

  ## Options

    * `:min_magnitude` - Minimum magnitude to consider (default: #{@min_magnitude})
    * `:frequency_bands` - List of `{start_bin, end_bin}` tuples (default: built-in bands)
  """
  def find_peaks(spectrogram, opts \\ []) do
    min_mag = Keyword.get(opts, :min_magnitude, @min_magnitude)
    bands = Keyword.get(opts, :frequency_bands, @frequency_bands)

    {num_frames, num_bins} = Nx.shape(spectrogram)

    # Clamp bands to actual spectrogram size
    bands = Enum.filter(bands, fn {start, _} -> start < num_bins end)
    bands = Enum.map(bands, fn {s, e} -> {s, min(e, num_bins)} end)

    for frame_idx <- 0..(num_frames - 1),
        {band_start, band_end} <- bands,
        band_end > band_start,
        reduce: [] do
      acc ->
        band_size = band_end - band_start

        band_slice =
          spectrogram
          |> Nx.slice([frame_idx, band_start], [1, band_size])
          |> Nx.reshape({band_size})

        max_val = Nx.reduce_max(band_slice) |> Nx.to_number()

        if max_val >= min_mag do
          max_idx = Nx.argmax(band_slice) |> Nx.to_number()
          freq_bin = band_start + max_idx
          [{frame_idx, freq_bin} | acc]
        else
          acc
        end
    end
    |> Enum.sort()
  end

  @doc """
  Returns the frequency bands used for peak detection.
  """
  def frequency_bands, do: @frequency_bands
end
