defmodule MusicRecognition.Peaks do
  @moduledoc """
  Detects spectral peaks in a spectrogram using a band-based approach.

  Divides the frequency range into bands and picks the loudest frequency
  in each band per time frame. This ensures we capture both bass and
  treble content.
  """

  @frequency_bands [
    {0, 10},
    {10, 20},
    {20, 40},
    {40, 80},
    {80, 160},
    {160, 512}
  ]

  @min_magnitude 1.0e-3

  @doc """
  Finds spectral peaks in a spectrogram.

  Returns a sorted list of `{frame_index, frequency_bin}` tuples.

  ## Options

    * `:min_magnitude` - Minimum magnitude threshold (default: #{@min_magnitude})
    * `:frequency_bands` - List of `{start_bin, end_bin}` tuples
  """
  def find_peaks(spectrogram, opts \\ []) do
    min_mag = Keyword.get(opts, :min_magnitude, @min_magnitude)
    {num_frames, num_bins} = Nx.shape(spectrogram)

    bands =
      Keyword.get(opts, :frequency_bands, @frequency_bands)
      |> Enum.map(fn {s, e} -> {s, min(e, num_bins)} end)
      |> Enum.filter(fn {s, e} -> s < num_bins and e > s end)

    for frame <- 0..(num_frames - 1),
        {band_start, band_end} <- bands,
        peak = find_band_peak(spectrogram, frame, band_start, band_end, min_mag),
        peak != nil do
      peak
    end
    |> Enum.sort()
  end

  defp find_band_peak(spectrogram, frame, band_start, band_end, min_mag) do
    band_size = band_end - band_start

    band =
      spectrogram
      |> Nx.slice([frame, band_start], [1, band_size])
      |> Nx.reshape({band_size})

    max_val = band |> Nx.reduce_max() |> Nx.to_number()

    if max_val >= min_mag do
      freq_bin = band_start + (band |> Nx.argmax() |> Nx.to_number())
      {frame, freq_bin}
    end
  end
end
