defmodule SortingBenchTest do
  use ExUnit.Case

  test "list_to_binary and binary_to_list roundtrip" do
    list = [5, 3, 1, 4, 2]
    binary = SortingBench.list_to_binary(list)
    assert byte_size(binary) == 5 * 8
    assert SortingBench.binary_to_list(binary) == list
  end

  test "generate_data creates correct number of elements" do
    data = SortingBench.generate_data(100)
    assert length(data) == 100
    assert Enum.all?(data, &is_integer/1)
  end

  describe "Rust NIF" do
    test "sort_list sorts correctly" do
      list = [5, 3, 1, 4, 2]
      assert SortingBench.RustNif.sort_list(list) == [1, 2, 3, 4, 5]
    end

    test "sort_binary sorts packed i64 binary" do
      list = [5, 3, 1, 4, 2]
      binary = SortingBench.list_to_binary(list)
      sorted_binary = SortingBench.RustNif.sort_binary(binary)
      assert SortingBench.binary_to_list(sorted_binary) == [1, 2, 3, 4, 5]
    end

    test "sort_binary_inplace sorts in-place" do
      list = [5, 3, 1, 4, 2]
      binary = SortingBench.list_to_binary(list) |> :binary.copy()
      assert SortingBench.RustNif.sort_binary_inplace(binary) == :ok
      assert SortingBench.binary_to_list(binary) == [1, 2, 3, 4, 5]
    end

    test "mmap full cycle works" do
      list = [5, 3, 1, 4, 2]
      binary = SortingBench.list_to_binary(list)

      mmap = SortingBench.RustNif.mmap_create(5)
      assert SortingBench.RustNif.mmap_write(mmap, binary) == :ok
      assert SortingBench.RustNif.mmap_sort(mmap) == :ok

      result = SortingBench.RustNif.mmap_read(mmap)
      assert SortingBench.binary_to_list(result) == [1, 2, 3, 4, 5]
    end
  end
end
