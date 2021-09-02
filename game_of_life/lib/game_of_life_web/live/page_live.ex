defmodule GameOfLifeWeb.PageLive do
  use GameOfLifeWeb, :live_view

  alias GameOfLife.Cell
  alias GameOfLifeWeb.PageLive.CellComponent

  @grid_size 20
  @update_frequency_in_ms 500

  @impl true
  def mount(_params, _session, socket) do
    cells = connected?(socket) && spawn_cells()

    {:ok, assign(socket, grid_size: @grid_size, cells: cells, started: false)}
  end

  @impl true
  def handle_event("start", _, %{assigns: %{started: started}} = socket) do
    unless started do
      send(self(), :tick)
    end

    {:noreply, assign(socket, started: true)}
  end

  @impl true
  def handle_event("stop", _, socket) do
    {:noreply, assign(socket, started: false)}
  end

  @impl true
  def handle_info({:set_alive, row, col, alive?}, socket) do
    send_update(CellComponent, id: "cell-#{row}-#{col}", alive?: alive?)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{started: started}} = socket) do
    if started, do: notify_cells_and_schedule_next_step(:tick, :tock, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tock, socket) do
    notify_cells_and_schedule_next_step(:tock, :tick, socket)
    {:noreply, socket}
  end

  defp spawn_cells() do
    for row <- 1..@grid_size do
      for col <- 1..@grid_size do
        {:ok, pid} =
          Cell.start_link(%{lv_pid: self(), row: row, col: col, boundaries: [1, @grid_size]})

        pid
      end
    end
    |> List.flatten()
  end

  defp notify_cells_and_schedule_next_step(
         current_step,
         next_step,
         %{assigns: %{cells: cells}} = socket
       ) do
    Enum.each(cells, &send(&1, current_step))
    Process.send_after(self(), next_step, @update_frequency_in_ms)
  end
end
