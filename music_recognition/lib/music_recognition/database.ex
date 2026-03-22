defmodule MusicRecognition.Database do
  @moduledoc """
  Stores and queries audio fingerprints using Explorer DataFrames.

  Matching works by joining on hash, computing time differences, and
  finding the song with the most time-aligned fingerprint matches.
  """

  alias Explorer.DataFrame, as: DF
  alias Explorer.Series

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
  """
  def insert(db, _song_id, []), do: db

  def insert(db, song_id, fingerprints) when is_binary(song_id) do
    n = length(fingerprints)

    DF.new(%{
      hash: fingerprints |> Enum.map(& &1.hash) |> Series.from_list(dtype: :u32),
      song_id: List.duplicate(song_id, n) |> Series.from_list(dtype: :string),
      time_offset: fingerprints |> Enum.map(& &1.time_offset) |> Series.from_list(dtype: :u32)
    })
    |> then(&DF.concat_rows(db, &1))
  end

  @doc """
  Queries the database with fingerprints from an audio sample.

  Returns a list of matches sorted by score descending:

      %{song_id: string, score: integer, confidence: float,
        probability: float, match_offset: integer}
  """
  def query(_db, []), do: []

  def query(db, query_fingerprints) do
    total_query = length(query_fingerprints)

    query_df =
      DF.new(%{
        hash: query_fingerprints |> Enum.map(& &1.hash) |> Series.from_list(dtype: :u32),
        query_offset: query_fingerprints |> Enum.map(& &1.time_offset) |> Series.from_list(dtype: :u32)
      })

    matches = DF.join(db, query_df, on: [:hash], how: :inner)

    if DF.n_rows(matches) == 0 do
      []
    else
      matches
      |> DF.put("time_diff", Series.subtract(matches["time_offset"], matches["query_offset"]))
      |> DF.group_by(["song_id", "time_diff"])
      |> DF.summarise(count: count(hash))
      |> DF.sort_by(desc: count)
      |> DF.distinct(["song_id"], keep_all: true)
      |> DF.sort_by(desc: count)
      |> DF.to_rows()
      |> to_results(total_query)
    end
  end

  def size(db), do: DF.n_rows(db)

  def num_songs(db), do: db["song_id"] |> Series.distinct() |> Series.count()

  def song_ids(db), do: db["song_id"] |> Series.distinct() |> Series.to_list()

  def save(db, path), do: DF.to_parquet(db, path)

  def load(path), do: DF.from_parquet!(path)

  defp to_results(rows, total_query) do
    total_score = rows |> Enum.map(& &1["count"]) |> Enum.sum()

    Enum.map(rows, fn row ->
      %{
        song_id: row["song_id"],
        score: row["count"],
        confidence: row["count"] / total_query,
        probability: if(total_score > 0, do: row["count"] / total_score, else: 0.0),
        match_offset: row["time_diff"]
      }
    end)
  end
end
