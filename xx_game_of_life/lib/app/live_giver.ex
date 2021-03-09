defmodule LiveGiver do
  use GenServer

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, [init_args])
  end

  def init(%{grid_size: grid_size, lv_pid: lv_pid} = state) do
    subscribe(grid_size, lv_pid)
    {:ok, Map.merge(state, %{neighbours: %{}})}
  end

  def handle_info(:tick, state), do: {:noreply, %{state | neighbours: %{}}}

  def handle_info(:tock, state) do
    spawn_cells(state)
    {:noreply, state}
  end

  def handle_info({:alive, x, y}, %{neighbours: neighbours} = state) do
    neighbours =
      case get_in(neighbours, [x, y]) do
        nil ->
          put_in(neighbours, [Access.key(x, %{}), y], 1)

        count ->
          put_in(neighbours, [x, y], count + 1)
      end

    {:noreply, %{state | neighbours: neighbours}}
  end

  defp subscribe(grid_size, lv_pid) do
    Phoenix.PubSub.subscribe(App.PubSub, Cell.gen_ticktock_topic(lv_pid))

    for x <- 1..grid_size, y <- 1..grid_size do
      Phoenix.PubSub.subscribe(App.PubSub, Cell.cell_ticktock_topic(lv_pid, x, y))
    end
  end

  defp spawn_cells(%{lv_pid: lv_pid, neighbours: neighbours, grid_size: grid_size}) do
    for x <- 1..grid_size, y <- 1..grid_size do
      if get_in(neighbours, [x, y]) == 3 do
        spawn_cell(lv_pid, x, y)
      end
    end
  end

  defp spawn_cell(lv_pid, x, y) do
    Phoenix.PubSub.broadcast!(
      App.PubSub,
      Cell.lifecycle_topic(lv_pid),
      {:spawn_cell, %{x: x, y: y}}
    )
  end
end
