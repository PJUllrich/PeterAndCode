defmodule GameOfLifeWeb.PageLive do
  use GameOfLifeWeb, :live_view

  alias GameOfLife.Cell
  alias GameOfLifeWeb.PageLive.CellComponent

  @grid_size 20
  @update_frequency_in_ms 500

  @impl true
  def mount(_params, _session, socket) do
    cells = connected?(socket) && spawn_cells()

    {:ok, assign(socket, grid_size: @grid_size, cells: cells)}
  end

  @impl true
  def handle_event("start", _, socket) do
    send(self(), :tick)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:set_alive, row, col, alive?}, socket) do
    send_update(CellComponent, id: "cell-#{row}-#{col}", alive?: alive?)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{cells: cells}} = socket) do
    Enum.each(cells, &send(&1, :tick))
    Process.send_after(self(), :tock, @update_frequency_in_ms)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tock, %{assigns: %{cells: cells}} = socket) do
    Enum.each(cells, &send(&1, :tock))
    Process.send_after(self(), :tick, @update_frequency_in_ms)
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
end
