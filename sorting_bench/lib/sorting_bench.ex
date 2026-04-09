defmodule SortingBench do
  @moduledoc """
  Elixir Sorting Benchmarks — comparing copy costs and sorting speeds.

  Approaches:
  1. Pure Elixir (Enum.sort)                       — baseline
  2. Rust NIF, list protocol                       — reference for copy costs
  3. Rust NIF, binary ref (safe copy)              — 1 memcpy
  4. Rust NIF, binary ref (in-place, unsafe)       — 0 copies
  5. Rust NIF, mmap shared memory (full cycle)     — 2 memcpy (write + read)
  6. Rust NIF, mmap shared memory (sort-only)      — 0 copies
  7. C Node via distributed Erlang                 — high copy cost, fast sort
  8. Nx (BinaryBackend)                            — pure Elixir tensor ops
  9. Nx (EXLA)                                     — JIT-compiled XLA
  10. Explorer (Polars)                            — Rust-backed DataFrame
  """

  @doc "Pack a list of integers into a native-endian binary of signed 64-bit ints."
  def list_to_binary(list) do
    for i <- list, into: <<>>, do: <<i::signed-native-64>>
  end

  @doc "Unpack a native-endian binary of signed 64-bit ints into a list."
  def binary_to_list(binary) do
    for <<i::signed-native-64 <- binary>>, do: i
  end

  @doc "Generate a list of `n` random integers in [0, max)."
  def generate_data(n, max \\ 1_000_000_000) do
    for _ <- 1..n, do: :rand.uniform(max)
  end
end
