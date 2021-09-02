defmodule GameOfLife.CellTest do
  use ExUnit.Case, async: true

  alias GameOfLife.Cell

  test "sets itself alive if alive upon creation" do
    Cell.start_link(%{alive?: true, lv_pid: self(), row: 0, col: 0})
    assert_received {:set_alive, 0, 0, true}
  end

  test "sets a deterministic process name upon creation" do
    {:ok, pid} = Cell.start_link(%{alive?: true, lv_pid: self(), row: 0, col: 0})
    expected_name = :"#{inspect(self())}-0-0"

    assert Process.whereis(expected_name) == pid
  end

  test "resets its state upon receiving a 'tick' message" do
    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 3, boundaries: [0, 0]})

    send(pid, :tick)

    assert %{alive_neighbours: 0} = :sys.get_state(pid)
  end

  test "bumps its alive_neighbours count if a :hello_neighbour message is received" do
    {:ok, pid} = Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 0})

    send(pid, :hello_neighbour)

    assert %{alive_neighbours: 1} = :sys.get_state(pid)
  end

  test "notifies its neighbours upon receiving a 'tick' message if alive" do
    cells = setup_3_by_3_grid()
    middle_cell = Enum.at(cells, 4)

    send(middle_cell, :tick)
    :timer.sleep(1)

    for cell <- cells do
      unless cell == middle_cell do
        assert_alive_neighbour_count_eq(cell, 1)
      end
    end
  end

  test "all cells compute the correct alive_neighbours count after one round" do
    cells = setup_3_by_3_grid()
    Enum.each(cells, &send(&1, :tick))

    :timer.sleep(100)
  end

  defp setup_3_by_3_grid() do
    for row <- 1..3, col <- 1..3 do
      {:ok, pid} =
        Cell.start_link(%{
          lv_pid: self(),
          row: row,
          col: col,
          alive?: true,
          alive_neighbours: 0,
          boundaries: [1, 3]
        })

      pid
    end
  end

  defp assert_alive_neighbour_count_eq(pid, count) do
    assert :sys.get_state(pid).alive_neighbours == count
  end
end
