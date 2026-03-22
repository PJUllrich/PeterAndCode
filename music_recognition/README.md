# Music Recognition

A Shazam-like audio fingerprinting and recognition system built in Elixir with [Nx](https://github.com/elixir-nx/nx) and [Explorer](https://github.com/elixir-explorer/explorer).

Implements the spectral fingerprinting algorithm from the original Shazam paper (Wang 2003): audio is converted to a spectrogram via STFT, spectral peaks are detected across frequency bands, peaks are paired into compact hashes, and matching uses time-aligned hash lookups in an Explorer DataFrame.

## Prerequisites

- Elixir >= 1.15
- `ffmpeg` installed and on PATH (for reading audio files)
- `ffplay` installed and on PATH (for audio playback in the demo, ships with ffmpeg)

## Setup

```bash
cd music_recognition
mix deps.get
```

## Quick Start

### 0. Download Songs

Download 100 CC-licensed songs from [Jamendo](https://www.jamendo.com/) (free, no account needed):

```bash
mix music.download
```

This downloads popular tracks across genres (pop, rock, jazz, electronic, etc.) into a `songs/` directory. The directory is gitignored.

Options:

```bash
# Download a different number of songs
mix music.download --count 50

# Download specific genres
mix music.download --tags rock,blues,jazz

# Download into a custom directory
mix music.download --dir /path/to/my/music
```

Or just use your own music — drop mp3/wav/flac/ogg files into any directory.

### 1. Build a Fingerprint Database

Point it at a directory containing audio files (mp3, wav, flac, ogg, m4a):

```elixir
iex -S mix

{db, stats} = MusicRecognition.build_database("/path/to/songs/")
# Fingerprinting song_a.mp3... 4832 fingerprints
# Fingerprinting song_b.mp3... 5121 fingerprints
# ...
# Database built: 100 songs, 487321 fingerprints
```

### 2. Recognize a Song

```elixir
{:ok, results} = MusicRecognition.recognize(db, "/path/to/sample.mp3")
IO.inspect(hd(results))
#=> %{
#=>   song_id: "bohemian_rhapsody.mp3",
#=>   score: 142,
#=>   confidence: 0.83,
#=>   probability: 0.71,
#=>   match_offset: 1823
#=> }
```

Each result contains:

| Field | Description |
|---|---|
| `song_id` | Filename of the matched song |
| `score` | Number of time-aligned fingerprint matches |
| `confidence` | `score / total_query_fingerprints` — how much of the query matched |
| `probability` | `score / sum_of_all_scores` — relative likelihood across all candidates (sums to 1.0) |
| `match_offset` | Frame index where the sample aligns in the matched song |

Options for `recognize/3`:

```elixir
# Use only 5 seconds starting 30s into the file
MusicRecognition.recognize(db, "sample.mp3", offset: 30, duration: 5)
```

### 3. Save and Load the Database

```elixir
MusicRecognition.save_database(db, "fingerprints.parquet")
db = MusicRecognition.load_database("fingerprints.parquet")
```

## Interactive Demo

The demo picks a random song, takes a random 5-15s clip, recognizes it, shows all matches with timestamps, and gives you playback commands.

### Run a Demo

```elixir
{db, _} = MusicRecognition.build_database("/path/to/songs/")
result = MusicRecognition.demo(db, "/path/to/songs/")
```

Output:

```
╔══════════════════════════════════════════╗
║          Music Recognition Demo          ║
╚══════════════════════════════════════════╝

Source:   hotel_california.mp3
Sample:   1:23.4 - 1:31.8 (8.4s)
Song len: 6:30.0

── Matches ──

  #  Song                               Score   Prob    Match Timestamp
  ───────────────────────────────────────────────────────────────────────────
  *1 hotel_california.mp3                142     71.3%   1:23.4
   2 desperado.mp3                       38      19.1%   2:05.1
   3 take_it_easy.mp3                    19      9.5%    0:44.2

── Playback Commands ──

  Play the sample:
    ffplay -nodisp -autoexit -ss 83.4 -t 8.4 "hotel_california.mp3"

  Play the best match at matched timestamp:
    ffplay -nodisp -autoexit -ss 83.4 -t 8.4 "hotel_california.mp3"
```

### Play Audio from the Demo Result

```elixir
# Play the random sample clip
MusicRecognition.play_sample(result)

# Play the best-matched song starting at the matched timestamp
MusicRecognition.play_match(result)
```

### Demo with a Specific Song

```elixir
alias MusicRecognition.Demo

Demo.run_with(db, "/path/to/songs/", "specific_song.mp3")
```

### Play Any File at a Specific Timestamp

```elixir
Demo.play("/path/to/song.mp3", offset: 65.0, duration: 10.0)
```

## Evaluation Framework

Test recognition accuracy across your entire library with random samples.

### Evaluate with Real Audio Files

```elixir
{db, _} = MusicRecognition.build_database("/path/to/songs/")

MusicRecognition.evaluate_directory(db, "/path/to/songs/",
  samples_per_song: 5,
  min_duration: 5,
  max_duration: 15,
  seed: 42
)
```

### Evaluate with Synthetic Tones (No Audio Files Needed)

```elixir
MusicRecognition.evaluate(
  num_songs: 20,
  samples_per_song: 5,
  noise_level: 0.02,
  seed: 42
)
```

Both print a detailed report:

```
╔══════════════════════════════════════════╗
║       Recognition Evaluation Report      ║
╚══════════════════════════════════════════╝

Overall Accuracy:  47 / 50 (94.0%)
Songs Tested:      10
Trials per Song:   5

── Per-Song Breakdown ──
  song_001                       [####################] 100.0% (5/5)
  song_002                       [##################--]  80.0% (4/5)
  ...

── Misidentifications ──
  song_002 → song_007 p=45.2% [12.3s + 6.1s]

── Ambiguous Matches (top 2 within 20% probability) ──
  song_005: song_005 (52.1%) vs song_003 (48.2%)
```

## Self-Test

Verify the pipeline works without any audio files:

```elixir
MusicRecognition.self_test()
```

## How It Works

```
Audio File (.mp3/.wav)
  |
  v  (ffmpeg -> raw PCM f32 samples at 11025 Hz)
Nx Tensor of samples
  |
  v  STFT: sliding 1024-sample Hann window, hop 512
Spectrogram (2D tensor: time x frequency)
  |
  v  Pick loudest bin per frame in 6 frequency bands
List of {frame_index, frequency_bin} peaks
  |
  v  Pair each anchor peak with nearby future target peaks
Fingerprints: hash = {freq1, freq2, time_delta} packed into u32
  |
  v  Store in Explorer DataFrame
+----------+---------+-------------+
| hash     | song_id | time_offset |
+----------+---------+-------------+
| 0xA3F1.. | song_42 | 1823        |
+----------+---------+-------------+
  |
  v  Match: join on hash, group by (song_id, time_diff), count
Results sorted by score with probability and match timestamp
```

## Project Structure

```
lib/
  music_recognition.ex              # Top-level API
  music_recognition/
    application.ex                  # OTP application
    audio.ex                        # Audio ingestion (ffmpeg + synthetic tones)
    spectrogram.ex                  # STFT via Nx.fft with Hann windowing
    peaks.ex                        # Band-based spectral peak detection
    fingerprint.ex                  # Combinatorial hash generation
    database.ex                     # Explorer DataFrame fingerprint store
    matcher.ex                      # Recognition pipeline orchestrator
    evaluation.ex                   # Accuracy benchmarking framework
    demo.ex                         # Interactive demo with playback
  mix/tasks/
    music.download.ex               # Mix task to download songs from Jamendo
test/
  music_recognition_test.exs        # Full pipeline tests
songs/                              # Downloaded songs (gitignored)
```
