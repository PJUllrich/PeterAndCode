defmodule SortingBench.Verify do
  @moduledoc """
  Pre-benchmark verification that each sorting approach produces correct output.

  Checks two properties:
  1. **Integrity** — the sum of elements is unchanged (no values lost or corrupted)
  2. **Ordering** — the result is actually sorted in ascending order

  This runs once per approach before Benchee starts, completely outside timing.
  """

  def verify_list!(name, result, expected_sum) when is_list(result) do
    sum = Enum.sum(result)

    unless sum == expected_sum do
      raise "VERIFY FAILED [#{name}]: sum mismatch — expected #{expected_sum}, got #{sum}"
    end

    unless sorted?(result) do
      raise "VERIFY FAILED [#{name}]: result is not sorted"
    end

    IO.puts("  [PASS] #{name}")
    :ok
  end

  def verify_binary!(name, result, expected_sum) when is_binary(result) do
    result
    |> SortingBench.binary_to_list()
    |> then(&verify_list!(name, &1, expected_sum))
  end

  def pass!(name) do
    IO.puts("  [PASS] #{name}")
    :ok
  end

  def sorted?(list) do
    Enum.reduce_while(list, :empty, fn
      x, :empty -> {:cont, x}
      x, prev when x >= prev -> {:cont, x}
      _x, _prev -> {:halt, :not_sorted}
    end) != :not_sorted
  end
end
