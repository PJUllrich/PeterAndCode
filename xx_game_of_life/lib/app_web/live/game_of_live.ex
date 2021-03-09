defmodule AppWeb.GameOfLive do
  use AppWeb, :live_view

  alias AppWeb.GameOfLive.CellComponent

  @grid_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(App.PubSub, Cell.lifecycle_topic(self()))
      create_random_grid()
    end

    {:ok, assign(socket, :grid_size, @grid_size)}
  end

  @impl true
  def handle_event("start", _params, socket) do
    send(self(), :tick)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:cell_spawned, %{x: x, y: y}}, socket) do
    send_update(CellComponent, id: cell_id(x, y), alive: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:cell_died, %{x: x, y: y}}, socket) do
    send_update(CellComponent, id: cell_id(x, y), alive: false)
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    Phoenix.PubSub.broadcast!(App.PubSub, Cell.gen_ticktock_topic(self()), :tick)
    Process.send_after(self(), :tock, 1000)
    {:noreply, socket}
  end

  def handle_info(:tock, socket) do
    Phoenix.PubSub.broadcast!(App.PubSub, Cell.gen_ticktock_topic(self()), :tock)
    Process.send_after(self(), :tick, 1000)
    {:noreply, socket}
  end

  def cell_id(x, y), do: "cell-#{x}-#{y}"

  defp create_random_grid do
    lv_pid = self()

    for _ <- 1..Enum.random((@grid_size * 2)..(@grid_size * 4)) do
      x = Enum.random(1..@grid_size)
      y = Enum.random(1..@grid_size)
      Cell.start_link(%{lv_pid: lv_pid, x: x, y: y})
    end
  end
end
