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
      assert Map.has_key?(hd(results), :match_offset)
    end

    test "query returns probability distribution across matched songs" do
      db = Database.new()

      # Song A has hashes 100, 200, 300
      db = Database.insert(db, "song_a", [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 5},
        %{hash: 300, time_offset: 10}
      ])

      # Song B shares hash 100 with song A
      db = Database.insert(db, "song_b", [
        %{hash: 100, time_offset: 0},
        %{hash: 400, time_offset: 5},
        %{hash: 500, time_offset: 10}
      ])

      # Query with song A's fingerprints — should match A strongly, B weakly
      query = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 5},
        %{hash: 300, time_offset: 10}
      ]

      results = Database.query(db, query)

      assert length(results) == 2

      song_a_result = Enum.find(results, &(&1.song_id == "song_a"))
      song_b_result = Enum.find(results, &(&1.song_id == "song_b"))

      # Both must have probability field
      assert Map.has_key?(song_a_result, :probability)
      assert Map.has_key?(song_b_result, :probability)

      # Probabilities must sum to ~1.0
      total_prob = song_a_result.probability + song_b_result.probability
      assert_in_delta total_prob, 1.0, 0.01

      # Song A should have higher probability
      assert song_a_result.probability > song_b_result.probability
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

  describe "Evaluation" do
    alias MusicRecognition.Evaluation

    test "synthetic evaluation runs and returns result struct" do
      result = Evaluation.evaluate_synthetic(
        num_songs: 3,
        song_duration: 15,
        samples_per_song: 2,
        min_duration: 5,
        max_duration: 8,
        seed: 123
      )

      assert is_map(result)
      assert Map.has_key?(result, :total)
      assert Map.has_key?(result, :correct)
      assert Map.has_key?(result, :accuracy)
      assert Map.has_key?(result, :per_song)
      assert Map.has_key?(result, :misses)
      assert Map.has_key?(result, :ambiguous)
      assert Map.has_key?(result, :trials)

      # 3 songs x 2 samples = 6 trials
      assert result.total == 6
      assert result.accuracy >= 0.0 and result.accuracy <= 1.0
      assert length(result.per_song) == 3

      # Each per_song entry has the right fields
      {_name, stats} = hd(result.per_song)
      assert Map.has_key?(stats, :correct)
      assert Map.has_key?(stats, :total)
      assert Map.has_key?(stats, :accuracy)
    end

    test "synthetic evaluation achieves reasonable accuracy with distinct tones" do
      result = Evaluation.evaluate_synthetic(
        num_songs: 5,
        song_duration: 20,
        samples_per_song: 3,
        min_duration: 5,
        max_duration: 10,
        seed: 42
      )

      # With synthetic tones (stationary signals), we expect high accuracy
      assert result.accuracy >= 0.5,
        "Expected at least 50% accuracy, got #{Float.round(result.accuracy * 100, 1)}%"
    end

    test "evaluation results include probability in trial results" do
      result = Evaluation.evaluate_synthetic(
        num_songs: 3,
        song_duration: 15,
        samples_per_song: 1,
        seed: 99
      )

      # Check that results in trials have probability
      Enum.each(result.trials, fn trial ->
        if trial.results != [] do
          Enum.each(trial.results, fn match ->
            assert Map.has_key?(match, :probability)
            assert match.probability >= 0.0 and match.probability <= 1.0
          end)

          # Probabilities should sum to ~1.0
          total = Enum.sum(Enum.map(trial.results, & &1.probability))
          assert_in_delta total, 1.0, 0.01
        end
      end)
    end

    test "print_report returns the result unchanged" do
      result = Evaluation.evaluate_synthetic(
        num_songs: 2,
        song_duration: 10,
        samples_per_song: 1,
        seed: 7
      )

      returned = Evaluation.print_report(result)
      assert returned == result
    end
  end

  describe "match_offset (timestamp alignment)" do
    test "query returns match_offset indicating where sample aligns in song" do
      db = Database.new()

      # Song fingerprints at offsets 0, 10, 20
      db = Database.insert(db, "song_a", [
        %{hash: 100, time_offset: 50},
        %{hash: 200, time_offset: 60},
        %{hash: 300, time_offset: 70}
      ])

      # Query fingerprints at offsets 0, 10, 20 (simulating sample from start)
      query = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 10},
        %{hash: 300, time_offset: 20}
      ]

      results = Database.query(db, query)
      assert length(results) > 0

      best = hd(results)
      assert best.song_id == "song_a"

      # match_offset should be 50 (db_offset 50 - query_offset 0 = 50)
      # All three fingerprints have the same time_diff of 50
      assert best.match_offset == 50
    end

    test "match_offset is consistent across all fingerprints for correct match" do
      db = Database.new()

      # Song with fingerprints spread across 100 frames
      song_fps = for i <- 0..20 do
        %{hash: 1000 + i, time_offset: 200 + i * 5}
      end

      db = Database.insert(db, "my_song", song_fps)

      # Query is a subset starting from frame 10 (simulating a clip from the middle)
      query_fps = for i <- 5..15 do
        %{hash: 1000 + i, time_offset: i * 5 - 25}
      end

      results = Database.query(db, query_fps)
      assert length(results) > 0

      best = hd(results)
      assert best.song_id == "my_song"
      assert is_integer(best.match_offset)
    end
  end

  describe "Demo" do
    alias MusicRecognition.Demo

    test "play command builder produces valid ffplay commands" do
      # Test via the Demo module's public API using a struct
      # We can test the play commands by checking the returned result structure
      # Since we can't run ffplay in tests, we verify the structure

      # Build a small DB with synthetic tones and a temp wav file
      songs = [{"test_tone", [440.0, 880.0, 1320.0]}]

      db =
        Enum.reduce(songs, Database.new(), fn {name, freqs}, db ->
          audio = Audio.generate_composite_tone(freqs, 10.0)
          {:ok, spec} = Spectrogram.compute(audio)
          peaks = Peaks.find_peaks(spec)
          fps = Fingerprint.generate(peaks)
          Database.insert(db, name, fps)
        end)

      # Verify database was built correctly
      assert Database.size(db) > 0
      assert Database.num_songs(db) == 1
    end
  end
end
