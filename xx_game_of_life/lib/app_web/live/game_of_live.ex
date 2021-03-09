defmodule AppWeb.GameOfLive do
  use AppWeb, :live_view

  alias AppWeb.GameOfLive.CellComponent

  @grid_size 40

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        {:ok, cell_supervisor_pid} = CellSupervisor.start_link(self())
        topic = "cell:lifecycle:#{inspect(self())}"
        Phoenix.PubSub.subscribe(App.PubSub, topic)
        socket = assign(socket, :cell_supervisor_pid, cell_supervisor_pid)
        create_random_grid(socket)

        socket
      else
        socket
      end

    {:ok, assign(socket, :grid_size, @grid_size)}
  end

  @impl true
  def handle_info({:cell_spawned, [x: x, y: y]}, socket) do
    send_update(CellComponent, id: cell_id(x, y), alive: true)
    {:noreply, socket}
  end

  def cell_id(x, y), do: "cell-#{x}-#{y}"

  defp create_random_grid(%{assigns: %{cell_supervisor_pid: cell_supervisor_pid}}) do
    lv_pid = self()

    for _ <- 1..Enum.random((@grid_size * 2)..(@grid_size * 4)) do
      x = Enum.random(1..@grid_size)
      y = Enum.random(1..@grid_size)
      CellSupervisor.start_child(cell_supervisor_pid, lv_pid: lv_pid, x: x, y: y)
    end
  end
end
