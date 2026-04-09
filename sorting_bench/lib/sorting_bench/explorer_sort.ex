defmodule SortingBench.ExplorerSort do
  @moduledoc """
  Sorting via the Explorer library (backed by Polars/Rust).

  Explorer uses Polars under the hood, which is a high-performance Rust
  DataFrame library. The sort runs natively in Rust.

  Copy cost: list → Series (one conversion) + sort + Series → list (one conversion).
  """

  def sort(list) do
    list
    |> Explorer.Series.from_list()
    |> Explorer.Series.sort()
    |> Explorer.Series.to_list()
  end
end
