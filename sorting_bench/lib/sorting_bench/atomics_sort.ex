defmodule SortingBench.AtomicsSort do
  @moduledoc """
  Sorting via Erlang's `:atomics` module — a mutable off-heap array of 64-bit
  integers.

  Implements in-place quicksort using `:atomics.get/2` and `:atomics.put/3`.
  Every element access goes through an atomic operation with memory barriers,
  making this comically slow for a single-threaded sort. But it's a fun
  demonstration of what `:atomics` can do.

  Copy cost profile:
    - List → atomics: O(n) puts (each an atomic write)
    - Sort: O(n log n) atomic get/put operations (quicksort in-place)
    - Atomics → list: O(n) gets (each an atomic read)

  The sort itself is pure Elixir — no native code involved. Each comparison
  and swap requires atomic memory barrier operations, adding significant
  constant overhead per operation.
  """

  def sort(list) do
    len = length(list)
    arr = :atomics.new(len, signed: true)

    # Load list into atomics array (1-indexed)
    list
    |> Enum.with_index(1)
    |> Enum.each(fn {val, i} -> :atomics.put(arr, i, val) end)

    # In-place quicksort
    quicksort(arr, 1, len)

    # Read back into a list
    for i <- 1..len do
      :atomics.get(arr, i)
    end
  end

  defp quicksort(_arr, lo, hi) when lo >= hi, do: :ok

  defp quicksort(arr, lo, hi) do
    pivot_idx = partition(arr, lo, hi)
    quicksort(arr, lo, pivot_idx - 1)
    quicksort(arr, pivot_idx + 1, hi)
  end

  defp partition(arr, lo, hi) do
    pivot = :atomics.get(arr, hi)
    {i, _} = Enum.reduce(lo..(hi - 1)//1, {lo, pivot}, fn j, {i, piv} ->
      if :atomics.get(arr, j) <= piv do
        swap(arr, i, j)
        {i + 1, piv}
      else
        {i, piv}
      end
    end)

    swap(arr, i, hi)
    i
  end

  defp swap(_arr, i, i), do: :ok

  defp swap(arr, i, j) do
    vi = :atomics.get(arr, i)
    vj = :atomics.get(arr, j)
    :atomics.put(arr, i, vj)
    :atomics.put(arr, j, vi)
  end
end
