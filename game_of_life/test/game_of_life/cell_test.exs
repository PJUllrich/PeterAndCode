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

    :timer.sleep(1)

    cells |> Enum.at(0) |> assert_alive_neighbour_count_eq(3)
    cells |> Enum.at(1) |> assert_alive_neighbour_count_eq(5)
    cells |> Enum.at(2) |> assert_alive_neighbour_count_eq(3)
    cells |> Enum.at(3) |> assert_alive_neighbour_count_eq(5)
    cells |> Enum.at(4) |> assert_alive_neighbour_count_eq(8)
    cells |> Enum.at(5) |> assert_alive_neighbour_count_eq(5)
    cells |> Enum.at(6) |> assert_alive_neighbour_count_eq(3)
    cells |> Enum.at(7) |> assert_alive_neighbour_count_eq(5)
    cells |> Enum.at(8) |> assert_alive_neighbour_count_eq(3)
  end

  test "live cells with 2 or 3 alive neighbours survive after receiving 'tock' and reset alive_neighbours" do
    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 2, alive?: true})

    send(pid, :tock)
    assert %{alive?: true, alive_neighbours: 0} = :sys.get_state(pid)

    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 1, col: 1, alive_neighbours: 3, alive?: true})

    send(pid, :tock)
    assert %{alive?: true, alive_neighbours: 0} = :sys.get_state(pid)
  end

  test "a dead cell with 3 alive neighbours becomes alive after receiving 'tock'" do
    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 3, alive?: false})

    send(pid, :tock)
    assert %{alive?: true, alive_neighbours: 0} = :sys.get_state(pid)
  end

  test "a live cell without 2 or 3 alive neighbours dies upon receiving 'tock'" do
    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 1, alive?: true})

    send(pid, :tock)
    assert %{alive?: false, alive_neighbours: 0} = :sys.get_state(pid)
  end

  test "a cell which becomes alive upon receiving 'tock' sends out a 'set_alive' message" do
    {:ok, pid} =
      Cell.start_link(%{lv_pid: self(), row: 0, col: 0, alive_neighbours: 3, alive?: false})

    send(pid, :tock)
    :timer.sleep(1)

    assert_received {:set_alive, 0, 0, true}
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
