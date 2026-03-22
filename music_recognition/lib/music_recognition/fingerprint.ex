defmodule MusicRecognition.Fingerprint do
  @moduledoc """
  Generates audio fingerprints from spectral peaks.

  Pairs each "anchor" peak with nearby "target" peaks that occur shortly
  after it. The hash packs both frequencies and their time delta into a
  single 32-bit integer.

  Hash layout:
    bits [0..9]   = anchor frequency (10 bits, max 1023)
    bits [10..19] = target frequency (10 bits, max 1023)
    bits [20..28] = time delta       (9 bits, max 511)
  """

  import Bitwise

  @target_zone_start 1
  @target_zone_end 30
  @max_fan_out 5

  @doc """
  Generates fingerprints from a sorted list of `{frame, freq_bin}` peaks.

  Returns a list of `%{hash: integer, time_offset: integer}` maps.
  """
  def generate(peaks, opts \\ []) do
    zone_start = Keyword.get(opts, :target_zone_start, @target_zone_start)
    zone_end = Keyword.get(opts, :target_zone_end, @target_zone_end)
    max_fan = Keyword.get(opts, :max_fan_out, @max_fan_out)

    sorted = Enum.sort_by(peaks, &elem(&1, 0))

    for {anchor_frame, anchor_freq} <- sorted,
        {target_frame, target_freq} <- targets_for(sorted, anchor_frame, zone_start, zone_end, max_fan) do
      %{
        hash: encode_hash(anchor_freq, target_freq, target_frame - anchor_frame),
        time_offset: anchor_frame
      }
    end
  end

  @doc """
  Encodes a fingerprint hash from its components.
  """
  def encode_hash(anchor_freq, target_freq, time_delta) do
    (anchor_freq &&& 0x3FF) |||
      ((target_freq &&& 0x3FF) <<< 10) |||
      ((time_delta &&& 0x1FF) <<< 20)
  end

  @doc """
  Decodes a fingerprint hash into `{anchor_freq, target_freq, time_delta}`.
  """
  def decode_hash(hash) do
    {hash &&& 0x3FF, (hash >>> 10) &&& 0x3FF, (hash >>> 20) &&& 0x1FF}
  end

  defp targets_for(sorted_peaks, anchor_frame, zone_start, zone_end, max_fan) do
    sorted_peaks
    |> Enum.filter(fn {frame, _} ->
      delta = frame - anchor_frame
      delta >= zone_start and delta <= zone_end
    end)
    |> Enum.take(max_fan)
  end
end
