defmodule MusicRecognitionTest do
  use ExUnit.Case

  alias MusicRecognition.{Audio, Spectrogram, Peaks, Fingerprint, Database}

  describe "Audio" do
    test "generates a sine wave tone with correct length" do
      tone = Audio.generate_tone(440.0, 1.0)
      assert Nx.shape(tone) == {Audio.sample_rate()}
    end

    test "generates composite tones normalized to [-1, 1]" do
      tone = Audio.generate_composite_tone([440.0, 880.0], 1.0)
      assert Nx.reduce_max(tone) |> Nx.to_number() <= 1.0
      assert Nx.reduce_min(tone) |> Nx.to_number() >= -1.0
    end
  end

  describe "Spectrogram" do
    test "computes a spectrogram from audio" do
      audio = Audio.generate_tone(440.0, 2.0)
      {:ok, spec} = Spectrogram.compute(audio)
      {num_frames, num_bins} = Nx.shape(spec)
      assert num_frames > 30
      assert num_bins == 513
    end

    test "returns error for very short audio" do
      audio = Nx.tensor([0.1, 0.2, 0.3], type: :f32)
      assert {:error, :audio_too_short} = Spectrogram.compute(audio)
    end

    test "spectrogram has energy at the expected frequency bin" do
      freq = 440.0
      audio = Audio.generate_tone(freq, 2.0)
      {:ok, spec} = Spectrogram.compute(audio)

      expected_bin = round(freq * 1024 / Audio.sample_rate())
      mid_frame = div(elem(Nx.shape(spec), 0), 2)

      peak_bin =
        spec
        |> Nx.slice([mid_frame, 0], [1, 513])
        |> Nx.reshape({513})
        |> Nx.argmax()
        |> Nx.to_number()

      assert abs(peak_bin - expected_bin) <= 2
    end
  end

  describe "Peaks" do
    test "finds peaks in a spectrogram" do
      audio = Audio.generate_composite_tone([440.0, 880.0], 2.0)
      {:ok, spec} = Spectrogram.compute(audio)
      peaks = Peaks.find_peaks(spec)

      assert length(peaks) > 0
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
      hash = Fingerprint.encode_hash(100, 200, 15)
      assert {100, 200, 15} = Fingerprint.decode_hash(hash)
    end
  end

  describe "Database" do
    test "creates empty database" do
      db = Database.new()
      assert Database.size(db) == 0
      assert Database.num_songs(db) == 0
    end

    test "inserts and queries fingerprints" do
      fps = [
        %{hash: 12345, time_offset: 0},
        %{hash: 67890, time_offset: 5},
        %{hash: 11111, time_offset: 10}
      ]

      db = Database.new() |> Database.insert("test_song", fps)
      assert Database.size(db) == 3
      assert Database.num_songs(db) == 1
      assert Database.song_ids(db) == ["test_song"]
    end

    test "query returns empty for no matches" do
      db = Database.new() |> Database.insert("song_a", [%{hash: 100, time_offset: 0}])
      assert Database.query(db, [%{hash: 999, time_offset: 0}]) == []
    end

    test "query matches identical fingerprints" do
      fps = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 5},
        %{hash: 300, time_offset: 10}
      ]

      db = Database.new() |> Database.insert("my_song", fps)
      [best | _] = Database.query(db, fps)

      assert best.song_id == "my_song"
      assert best.score == 3
      assert Map.has_key?(best, :match_offset)
    end

    test "query returns probability distribution across matched songs" do
      db =
        Database.new()
        |> Database.insert("song_a", [
          %{hash: 100, time_offset: 0},
          %{hash: 200, time_offset: 5},
          %{hash: 300, time_offset: 10}
        ])
        |> Database.insert("song_b", [
          %{hash: 100, time_offset: 0},
          %{hash: 400, time_offset: 5},
          %{hash: 500, time_offset: 10}
        ])

      query = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 5},
        %{hash: 300, time_offset: 10}
      ]

      results = Database.query(db, query)
      assert length(results) == 2

      a = Enum.find(results, &(&1.song_id == "song_a"))
      b = Enum.find(results, &(&1.song_id == "song_b"))

      assert_in_delta a.probability + b.probability, 1.0, 0.01
      assert a.probability > b.probability
    end
  end

  describe "end-to-end recognition" do
    test "recognizes a song from its own segment" do
      songs = [
        {"song_a", [440.0, 880.0, 1320.0]},
        {"song_b", [523.25, 659.25, 783.99]},
        {"song_c", [349.23, 698.46, 1046.5]}
      ]

      db =
        Enum.reduce(songs, Database.new(), fn {name, freqs}, db ->
          {:ok, fps} = freqs |> Audio.generate_composite_tone(20.0) |> MusicRecognition.fingerprint_tensor()
          Database.insert(db, name, fps)
        end)

      Enum.each(songs, fn {name, freqs} ->
        sample = Audio.generate_composite_tone(freqs, 5.0)
        {:ok, [best | _]} = MusicRecognition.recognize_tensor(db, sample)

        assert best.song_id == name, "Expected #{name}, got #{best.song_id}"
        assert best.confidence > 0.1
      end)
    end
  end

  describe "match_offset" do
    test "returns correct alignment offset" do
      db =
        Database.new()
        |> Database.insert("song_a", [
          %{hash: 100, time_offset: 50},
          %{hash: 200, time_offset: 60},
          %{hash: 300, time_offset: 70}
        ])

      query = [
        %{hash: 100, time_offset: 0},
        %{hash: 200, time_offset: 10},
        %{hash: 300, time_offset: 20}
      ]

      [best | _] = Database.query(db, query)
      assert best.song_id == "song_a"
      assert best.match_offset == 50
    end

    test "match_offset is an integer for correct matches" do
      song_fps = for i <- 0..20, do: %{hash: 1000 + i, time_offset: 200 + i * 5}
      query_fps = for i <- 5..15, do: %{hash: 1000 + i, time_offset: i * 5 - 25}

      db = Database.new() |> Database.insert("my_song", song_fps)
      [best | _] = Database.query(db, query_fps)

      assert best.song_id == "my_song"
      assert is_integer(best.match_offset)
    end
  end

  describe "Evaluation" do
    alias MusicRecognition.Evaluation

    test "synthetic evaluation returns result struct" do
      result =
        Evaluation.evaluate_synthetic(
          num_songs: 3,
          song_duration: 15,
          samples_per_song: 2,
          min_duration: 5,
          max_duration: 8,
          seed: 123
        )

      assert result.total == 6
      assert result.accuracy >= 0.0 and result.accuracy <= 1.0
      assert length(result.per_song) == 3

      {_name, stats} = hd(result.per_song)
      assert is_number(stats.accuracy)
    end

    test "achieves reasonable accuracy with distinct tones" do
      result =
        Evaluation.evaluate_synthetic(
          num_songs: 5,
          song_duration: 20,
          samples_per_song: 3,
          min_duration: 5,
          max_duration: 10,
          seed: 42
        )

      assert result.accuracy >= 0.5,
        "Expected at least 50% accuracy, got #{Float.round(result.accuracy * 100, 1)}%"
    end

    test "results include probability summing to 1.0" do
      result =
        Evaluation.evaluate_synthetic(
          num_songs: 3,
          song_duration: 15,
          samples_per_song: 1,
          seed: 99
        )

      for trial <- result.trials, trial.results != [] do
        assert Enum.all?(trial.results, &(&1.probability >= 0.0 and &1.probability <= 1.0))

        total = trial.results |> Enum.map(& &1.probability) |> Enum.sum()
        assert_in_delta total, 1.0, 0.01
      end
    end

    test "print_report returns the result unchanged" do
      result =
        Evaluation.evaluate_synthetic(
          num_songs: 2,
          song_duration: 10,
          samples_per_song: 1,
          seed: 7
        )

      assert Evaluation.print_report(result) == result
    end
  end
end
