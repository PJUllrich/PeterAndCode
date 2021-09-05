defmodule GameOfLife.Cell do
  use GenServer

  def start_link(init_args) do
    alive? = Map.get(init_args, :alive?, Enum.random([true, false]))
    name = Map.get(init_args, :name, gen_name(init_args))
    state = Map.merge(%{alive?: alive?, alive_neighbours: 0}, init_args)

    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    if alive?, do: set_alive(state)
    {:ok, state}
  end

  def handle_info(:tick, %{alive?: alive?} = state) do
    if alive?, do: notify_neighbours(state)
    {:noreply, state}
  end

  def handle_info(:tock, state) do
    state = determine_new_life_state(state)
    {:noreply, state}
  end

  def handle_info(:hello_neighbour, state) do
    state = Map.update!(state, :alive_neighbours, &(&1 + 1))
    {:noreply, state}
  end

  defp notify_neighbours(%{
         lv_pid: lv_pid,
         row: own_row,
         col: own_col,
         boundaries: [min_idx, max_idx]
       }) do
    min_row = max(own_row - 1, min_idx)
    max_row = min(own_row + 1, max_idx)
    min_col = max(own_col - 1, min_idx)
    max_col = min(own_col + 1, max_idx)

    for row <- min_row..max_row, col <- min_col..max_col do
      unless row == own_row && col == own_col do
        name = gen_name(%{lv_pid: lv_pid, row: row, col: col})
        send(name, :hello_neighbour)
      end
    end
  end

  defp determine_new_life_state(%{alive?: alive?, alive_neighbours: alive_neighbours} = state) do
    new_alive? =
      cond do
        alive? && alive_neighbours in [2, 3] ->
          true

        not alive? && alive_neighbours == 3 ->
          true

        true ->
          false
      end

    state = %{state | alive?: new_alive?, alive_neighbours: 0}
    if new_alive? != alive?, do: set_alive(state)

    state
  end

  defp set_alive(%{lv_pid: lv_pid, row: row, col: col, alive?: alive?}) do
    send(lv_pid, {:set_alive, row, col, alive?})
  end

  defp gen_name(%{lv_pid: lv_pid, row: row, col: col}) do
    :"#{inspect(lv_pid)}-#{row}-#{col}"
  end
end
