defmodule SortingBench.DuxSort do
  @moduledoc """
  Sorting via the Dux library (backed by DuckDB).

  Dux compiles operations to SQL and executes them through DuckDB's
  analytical engine. The sort runs natively inside DuckDB.

  Copy cost: list → DataFrame (one conversion) + sort + DataFrame → list
  (one conversion).
  """

  def sort(list) do
    list
    |> Enum.map(&%{v: &1})
    |> Dux.from_list()
    |> Dux.sort_by(:v)
    |> Dux.to_columns(atom_keys: true)
    |> Map.fetch!(:v)
  end
end
