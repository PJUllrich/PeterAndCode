defmodule MusicRecognition.Database do
  @moduledoc """
  Stores and queries audio fingerprints using Explorer DataFrames.

  The database is a simple table with three columns:
    - `hash` (u32): The fingerprint hash encoding freq1, freq2, and time delta
    - `song_id` (string): Identifier for the song (typically the filename)
    - `time_offset` (u32): Frame index where this fingerprint's anchor occurs

  Matching works by:
    1. Looking up all database entries that share a hash with the query
    2. Computing the time difference (db_offset - query_offset) for each match
    3. Grouping by (song_id, time_difference) and counting
    4. The song with the most consistent time-aligned matches wins
  """

  alias Explorer.DataFrame, as: DF
  alias Explorer.Series

  @type t :: Explorer.DataFrame.t()

  @doc """
  Creates an empty fingerprint database.
  """
  def new do
    DF.new(%{
      hash: Series.from_list([], dtype: :u32),
      song_id: Series.from_list([], dtype: :string),
      time_offset: Series.from_list([], dtype: :u32)
    })
  end

  @doc """
  Inserts fingerprints for a song into the database.

  `fingerprints` is a list of `%{hash: integer, time_offset: integer}` maps
  as returned by `MusicRecognition.Fingerprint.generate/2`.

  Returns a new DataFrame with the fingerprints appended.
  """
  def insert(db, song_id, fingerprints) when is_binary(song_id) do
    if fingerprints == [] do
      db
    else
      new_rows =
        DF.new(%{
          hash: Series.from_list(Enum.map(fingerprints, & &1.hash), dtype: :u32),
          song_id: Series.from_list(List.duplicate(song_id, length(fingerprints)), dtype: :string),
          time_offset: Series.from_list(Enum.map(fingerprints, & &1.time_offset), dtype: :u32)
        })

      DF.concat_rows(db, new_rows)
    end
  end

  @doc """
  Queries the database with a set of fingerprints from an audio sample.

  Returns a list of `%{song_id: string, score: integer, confidence: float}`
  sorted by score descending. The score is the number of time-aligned
  fingerprint matches. Confidence is score / total_query_fingerprints.
  """
  def query(db, query_fingerprints) do
    if query_fingerprints == [] do
      []
    else
      query_df =
        DF.new(%{
          hash: Series.from_list(Enum.map(query_fingerprints, & &1.hash), dtype: :u32),
          query_offset: Series.from_list(Enum.map(query_fingerprints, & &1.time_offset), dtype: :u32)
        })

      total_query = length(query_fingerprints)

      # Join on hash to find all matching fingerprints
      matches = DF.join(db, query_df, on: [:hash], how: :inner)

      if DF.n_rows(matches) == 0 do
        []
      else
        # Compute time difference: db_offset - query_offset
        # Matching fingerprints from the same song should have a consistent time_diff
        time_diff =
          Series.subtract(matches["time_offset"], matches["query_offset"])

        matches = DF.put(matches, "time_diff", time_diff)

        # Group by song_id + time_diff to find the best time-aligned cluster
        grouped =
          matches
          |> DF.group_by(["song_id", "time_diff"])
          |> DF.summarise(count: count(hash))
          |> DF.discard("time_diff")

        # For each song, take the maximum count across all time alignments
        results =
          grouped
          |> DF.group_by("song_id")
          |> DF.summarise(score: max(count))
          |> DF.sort_by(desc: score)

        rows = DF.to_rows(results)
        total_score = Enum.sum(Enum.map(rows, & &1["score"]))

        rows
        |> Enum.map(fn row ->
          %{
            song_id: row["song_id"],
            score: row["score"],
            confidence: row["score"] / total_query,
            probability: if(total_score > 0, do: row["score"] / total_score, else: 0.0)
          }
        end)
      end
    end
  end

  @doc """
  Returns the number of fingerprints in the database.
  """
  def size(db), do: DF.n_rows(db)

  @doc """
  Returns the number of unique songs in the database.
  """
  def num_songs(db) do
    db["song_id"] |> Series.distinct() |> Series.count()
  end

  @doc """
  Lists all song IDs in the database.
  """
  def song_ids(db) do
    db["song_id"] |> Series.distinct() |> Series.to_list()
  end

  @doc """
  Saves the database to a Parquet file for persistence.
  """
  def save(db, path) do
    DF.to_parquet(db, path)
  end

  @doc """
  Loads a database from a Parquet file.
  """
  def load(path) do
    DF.from_parquet!(path)
  end
end
