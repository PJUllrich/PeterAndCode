defmodule MusicRecognitionTest do
  use ExUnit.Case

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database, Matcher}

  describe "Audio" do
    test "generates a sine wave tone with correct length" do
      tone = Audio.generate_tone(440.0, 1.0)
      assert Nx.shape(tone) == {Audio.sample_rate()}
    end

    test "generates composite tones normalized to [-1, 1]" do
      tone = Audio.generate_composite_tone([440.0, 880.0], 1.0)
      max_val = Nx.reduce_max(tone) |> Nx.to_number()
      min_val = Nx.reduce_min(tone) |> Nx.to_number()
      assert max_val <= 1.0
      assert min_val >= -1.0
    end
  end

  describe "Spectrogram" do
    test "computes a spectrogram from audio" do
      audio = Audio.generate_tone(440.0, 2.0)
      {:ok, spec} = Spectrogram.compute(audio)
      {num_frames, num_bins} = Nx.shape(spec)
      # At 11025 Hz, 2s of audio, window=1024, hop=512: ~41 frames
      assert num_frames > 30
      # num_bins = window_size/2 + 1 = 513
      assert num_bins == 513
    end

    test "returns error for very short audio" do
      audio = Nx.tensor([0.1, 0.2, 0.3], type: :f32)
      assert {:error, :audio_too_short} = Spectrogram.compute(audio)
    end

    test "spectrogram has energy at the expected frequency bin for a pure tone" do
      freq = 440.0
      audio = Audio.generate_tone(freq, 2.0)
      {:ok, spec} = Spectrogram.compute(audio)

      # Expected bin for 440 Hz: 440 / (11025/1024) ≈ 40.9 → bin 41
      expected_bin = round(freq * 1024 / Audio.sample_rate())

      # Check that the max bin in the middle frame is near the expected frequency
      mid_frame = div(elem(Nx.shape(spec), 0), 2)
      frame = Nx.slice(spec, [mid_frame, 0], [1, 513]) |> Nx.reshape({513})
      peak_bin = Nx.argmax(frame) |> Nx.to_number()

      assert abs(peak_bin - expected_bin) <= 2
    end
  end

  describe "Peaks" do
    test "finds peaks in a spectrogram" do
      audio = Audio.generate_composite_tone([440.0, 880.0], 2.0)
      {:ok, spec} = Spectrogram.compute(audio)
      peaks = Peaks.find_peaks(spec)

      assert length(peaks) > 0
      # Each peak is {frame_index, freq_bin}
      assert {frame, freq} = hd(peaks)
      assert is_integer(frame)
      assert is_integer(freq)
    end
  end

  describe "Fingerprint" do
    test "generates fingerprints from peaks" do
      peaks = [{0, 40}, {1, 80}, {2, 41}, {5, 160}, {10, 42}]
      fingerprints = Fingerprint.generate(peaks)

      assert length(fingerprints) > 0
      assert %{hash: hash, time_offset: offset} = hd(fingerprints)
      assert is_integer(hash)
      assert is_integer(offset)
    end

    test "hash encoding and decoding round-trips" do
      {af, tf, td} = {100, 200, 15}
      hash = Fingerprint.encode_hash(af, tf, td)
      assert {^af, ^tf, ^td} = Fingerprint.decode_hash(hash)
    end
  end

  describe "Database" do
    test "creates empty database" do
      db = Database.new()
      assert Database.size(db) == 0
      assert Database.num_songs(db) == 0
    end

    test "inserts and queries fingerprints" do
      db = Database.new()

      fps = [
        %{hash: 12345, time_offset: 0},
        %{hash: 67890, time_offset: 5},
        %{hash: 11111, time_offset: 10}
      ]

      db = Database.insert(db, "test_song", fps)
      assert Database.size(db) == 3
      assert Database.num_songs(db) == 1
      assert Database.song_ids(db) == ["test_song"]
    end

    test "query returns empty for no matches" do
      db = Database.new()
      db = Database.insert(db, "song_a", [%{hash: 100, time_offset: 0}])
      results = Database.query(db, [%{hash: 999, time_offset: 0}])
      assert results == []
    end

    test "query matches identical fingerprints" do
      db = Database.new()

      fps = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 5},
        %{hash: 300, time_offset: 10}
      ]

      db = Database.insert(db, "my_song", fps)
      results = Database.query(db, fps)

      assert length(results) > 0
      assert hd(results).song_id == "my_song"
      assert hd(results).score == 3
    end
  end

  describe "end-to-end recognition with synthetic tones" do
    test "recognizes a song from its own segment" do
      # Build database with 3 distinct songs
      songs = [
        {"song_a", [440.0, 880.0, 1320.0]},
        {"song_b", [523.25, 659.25, 783.99]},
        {"song_c", [349.23, 698.46, 1046.5]}
      ]

      db =
        Enum.reduce(songs, Database.new(), fn {name, freqs}, db ->
          audio = Audio.generate_composite_tone(freqs, 20.0)
          {:ok, spec} = Spectrogram.compute(audio)
          peaks = Peaks.find_peaks(spec)
          fps = Fingerprint.generate(peaks)
          Database.insert(db, name, fps)
        end)

      # Try to recognize each song from a 5-second sample
      Enum.each(songs, fn {name, freqs} ->
        sample = Audio.generate_composite_tone(freqs, 5.0)
        {:ok, results} = Matcher.recognize_tensor(db, sample)

        assert length(results) > 0, "No results for #{name}"
        best = hd(results)
        assert best.song_id == name, "Expected #{name}, got #{best.song_id}"
        assert best.confidence > 0.1, "Confidence too low for #{name}: #{best.confidence}"
      end)
    end
  end
end
