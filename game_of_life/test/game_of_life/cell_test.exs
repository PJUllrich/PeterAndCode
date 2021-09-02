defmodule GameOfLife.CellTest do
  use ExUnit.Case

  alias GameOfLife.Cell

  test "sets itself alive if alive upon creation" do
    Cell.start_link(%{alive?: true, lv_pid: self(), row: 0, col: 0})
    assert_received {:set_alive, 0, 0, true}
  end
end
