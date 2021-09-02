defmodule GameOfLife.Cell do
  use GenServer

  def start_link(init_args) do
    alive? = Map.get(init_args, :alive?, Enum.random([true, false]))
    name = Map.get(init_args, :name, gen_name(init_args))
    args = Map.merge(init_args, %{alive?: alive?})

    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(%{alive?: alive?} = args) do
    if alive?, do: set_alive(args)
    {:ok, args}
  end

  def handle_info(:tick, %{alive?: alive?} = args) do
    if alive?, do: notify_neighbours(args)
    {:noreply, %{args | alive_neighbours: 0}}
  end

  def handle_info(:hello_neighbour, args) do
    args = Map.update!(args, :alive_neighbours, &(&1 + 1))
    {:noreply, args}
  end

  defp set_alive(%{lv_pid: lv_pid, row: row, col: col, alive?: alive?}) do
    send(lv_pid, {:set_alive, row, col, alive?})
  end

  defp gen_name(%{lv_pid: lv_pid, row: row, col: col}) do
    :"#{inspect(lv_pid)}-#{row}-#{col}"
  end

  defp notify_neighbours(%{
         lv_pid: lv_pid,
         row: own_row,
         col: own_col,
         boundaries: [min_idx, max_idx]
       }) do
    for row <- min_idx..max_idx, col <- min_idx..max_idx do
      unless row == own_row && col == own_col do
        name = gen_name(%{lv_pid: lv_pid, row: row, col: col})
        send(name, :hello_neighbour)
      end
    end
  end
end
