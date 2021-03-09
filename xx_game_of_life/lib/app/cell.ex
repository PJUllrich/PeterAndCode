defmodule Cell do
  use GenServer

  def start_link(pid_and_coordinates) do
    GenServer.start_link(
      __MODULE__,
      pid_and_coordinates
    )
  end

  def init(state) do
    broadcast_spawned(state)
    subscribe_ticktock(state)
    state = Map.merge(state, %{neighbours: 0})

    {:ok, state}
  end

  def handle_info(:tick, state) do
    send(self(), :broadcast_alive)
    {:noreply, %{state | neighbours: 0}}
  end

  def handle_info(:tock, %{neighbours: neighbours} = state) do
    if neighbours == 2 || neighbours == 3 do
      {:noreply, state}
    else
      broadcast_died(state)
      {:stop, :normal, state}
    end
  end

  def handle_info(:broadcast_alive, %{lv_pid: lv_pid, x: x, y: y} = state) do
    for xn <- (x - 1)..(x + 1),
        yn <- (y - 1)..(y + 1) do
      if yn != y, do: broadcast_alive(lv_pid, xn, yn)
    end

    {:noreply, state}
  end

  def handle_info(:alive, %{neighbours: neighbours} = state) do
    {:noreply, %{state | neighbours: neighbours + 1}}
  end

  def lifecycle_topic(pid), do: "cell:lifecycle:#{inspect(pid)}"
  def gen_ticktock_topic(pid), do: "cell:ticktock:#{inspect(pid)}"
  def cell_ticktock_topic(pid, x, y), do: "cell:ticktock:#{inspect(pid)}:#{x}-#{y}"

  defp broadcast_spawned(%{lv_pid: lv_pid, x: x, y: y}) do
    Phoenix.PubSub.broadcast(
      App.PubSub,
      lifecycle_topic(lv_pid),
      {:cell_spawned, %{x: x, y: y}}
    )
  end

  defp broadcast_died(%{lv_pid: lv_pid, x: x, y: y}) do
    Phoenix.PubSub.broadcast(
      App.PubSub,
      lifecycle_topic(lv_pid),
      {:cell_died, %{x: x, y: y}}
    )
  end

  defp broadcast_alive(lv_pid, x, y) do
    Phoenix.PubSub.broadcast(
      App.PubSub,
      cell_ticktock_topic(lv_pid, x, y),
      :alive
    )
  end

  defp subscribe_ticktock(%{lv_pid: lv_pid, x: x, y: y}) do
    Phoenix.PubSub.subscribe(App.PubSub, gen_ticktock_topic(lv_pid))
    Phoenix.PubSub.subscribe(App.PubSub, cell_ticktock_topic(lv_pid, x, y))
  end
end
