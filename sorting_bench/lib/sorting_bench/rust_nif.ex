defmodule SortingBench.RustNif do
  use Rustler, otp_app: :sorting_bench, crate: "sorting_nif"

  @doc "Sort a list of integers via NIF list protocol (full copy in/out)"
  def sort_list(_list), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sort a packed-i64 binary (refc binary in, new binary out)"
  def sort_binary(_binary), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sort a packed-i64 binary IN-PLACE (unsafe, zero copy)"
  def sort_binary_inplace(_binary), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Create a shared-memory mmap region for `num_elements` i64s"
  def mmap_create(_num_elements), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Write a packed-i64 binary into the mmap region"
  def mmap_write(_resource, _binary), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sort the mmap region in-place (zero copy)"
  def mmap_sort(_resource), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Read the mmap region back as a binary"
  def mmap_read(_resource), do: :erlang.nif_error(:nif_not_loaded)
end
