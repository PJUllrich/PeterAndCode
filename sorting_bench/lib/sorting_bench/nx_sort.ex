defmodule SortingBench.NxSort do
  @moduledoc """
  Sorting via Nx tensors.

  Two backends are benchmarked:
  - BinaryBackend (pure Elixir, no native acceleration)
  - EXLA (JIT-compiled via XLA, runs on CPU)
  """

  def sort_binary_backend(list) do
    list
    |> Nx.tensor(type: :s64, backend: Nx.BinaryBackend)
    |> Nx.sort()
    |> Nx.to_list()
  end

  def sort_exla_backend(list) do
    list
    |> Nx.tensor(type: :s64, backend: EXLA.Backend)
    |> Nx.sort()
    |> Nx.to_list()
  end
end
