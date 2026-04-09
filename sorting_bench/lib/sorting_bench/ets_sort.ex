defmodule SortingBench.EtsSort do
  @moduledoc """
  Sorting via ETS ordered_set.

  Inserts all elements as keys into an ETS table with type `ordered_set`,
  which maintains them in an AVL tree (sorted by Erlang term ordering).
  Then extracts the sorted keys with `:ets.tab2list/1`.

  Copy cost profile:
    - Each insert copies the term into ETS-owned memory (off-heap)
    - tab2list copies all terms back into a new list on the process heap
    - The AVL tree keeps elements sorted at all times (O(log n) per insert)

  This is fundamentally different from comparison sorts: it builds
  a balanced search tree instead of sorting a flat array. Interesting
  to see how it compares at scale.

  Note: ETS ordered_set deduplicates keys. We use {value, index} tuples
  to preserve duplicates.
  """

  def sort(list) do
    table = :ets.new(:sort_bench, [:ordered_set, :private])

    list
    |> Enum.with_index()
    |> Enum.each(fn {val, idx} -> :ets.insert(table, {{val, idx}}) end)

    result = :ets.tab2list(table) |> Enum.map(fn {{val, _idx}} -> val end)
    :ets.delete(table)
    result
  end
end
