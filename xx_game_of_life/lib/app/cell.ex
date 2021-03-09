defmodule Cell do
  use GenServer

  def start_link(pid_and_coordinates) do
    GenServer.start_link(
      __MODULE__,
      pid_and_coordinates,
      name: {:via, Registry, {CellRegistry, pid_and_coordinates}}
    )
  end

  def init([lv_pid: lv_pid, x: x, y: y] = state) do
    topic = "cell:lifecycle:#{inspect(lv_pid)}"

    Phoenix.PubSub.broadcast(
      App.PubSub,
      topic,
      {:cell_spawned, [x: x, y: y]}
    )

    {:ok, state}
  end
end
