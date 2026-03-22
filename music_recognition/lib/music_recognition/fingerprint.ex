defmodule MusicRecognition.Fingerprint do
  @moduledoc """
  Generates audio fingerprints from spectral peaks.

  A fingerprint is created by pairing an "anchor" peak with nearby "target"
  peaks that occur shortly after it. The hash combines the frequencies of
  both peaks and their time difference, creating a compact signature that
  is robust to noise and time-shifting.

  Hash structure (32-bit integer):
    bits [0..9]   = anchor frequency bin (10 bits, max 1023)
    bits [10..19] = target frequency bin (10 bits, max 1023)
    bits [20..28] = time delta in frames (9 bits, max 511)

  Each fingerprint also stores the absolute time offset of the anchor point,
  which is used during matching to verify temporal consistency.
  """

  # How far ahead (in frames) to look for target peaks
  @target_zone_start 1
  @target_zone_end 30

  # Maximum number of target peaks to pair with each anchor
  @max_fan_out 5

  @type fingerprint :: %{
          hash: non_neg_integer(),
          time_offset: non_neg_integer()
        }

  @doc """
  Generates fingerprints from a list of `{frame_index, frequency_bin}` peaks.

  Returns a list of `%{hash: integer, time_offset: integer}` maps.

  ## Options

    * `:target_zone_start` - Min frame distance for target peaks (default: #{@target_zone_start})
    * `:target_zone_end` - Max frame distance for target peaks (default: #{@target_zone_end})
    * `:max_fan_out` - Max targets per anchor (default: #{@max_fan_out})
  """
  def generate(peaks, opts \\ []) do
    zone_start = Keyword.get(opts, :target_zone_start, @target_zone_start)
    zone_end = Keyword.get(opts, :target_zone_end, @target_zone_end)
    max_fan = Keyword.get(opts, :max_fan_out, @max_fan_out)

    sorted_peaks = Enum.sort_by(peaks, fn {frame, _freq} -> frame end)

    sorted_peaks
    |> Enum.flat_map(fn {anchor_frame, anchor_freq} ->
      # Find target peaks in the target zone
      targets =
        sorted_peaks
        |> Enum.filter(fn {target_frame, _target_freq} ->
          delta = target_frame - anchor_frame
          delta >= zone_start and delta <= zone_end
        end)
        |> Enum.take(max_fan)

      Enum.map(targets, fn {target_frame, target_freq} ->
        time_delta = target_frame - anchor_frame
        hash = encode_hash(anchor_freq, target_freq, time_delta)

        %{hash: hash, time_offset: anchor_frame}
      end)
    end)
  end

  @doc """
  Encodes a fingerprint hash from its components.
  """
  def encode_hash(anchor_freq, target_freq, time_delta) do
    import Bitwise

    (anchor_freq &&& 0x3FF) |||
      ((target_freq &&& 0x3FF) <<< 10) |||
      ((time_delta &&& 0x1FF) <<< 20)
  end

  @doc """
  Decodes a fingerprint hash into its components.
  Returns `{anchor_freq, target_freq, time_delta}`.
  """
  def decode_hash(hash) do
    import Bitwise

    anchor_freq = hash &&& 0x3FF
    target_freq = (hash >>> 10) &&& 0x3FF
    time_delta = (hash >>> 20) &&& 0x1FF

    {anchor_freq, target_freq, time_delta}
  end
end
