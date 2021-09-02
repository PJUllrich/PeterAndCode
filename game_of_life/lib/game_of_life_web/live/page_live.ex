defmodule GameOfLifeWeb.PageLive do
  use GameOfLifeWeb, :live_view

  alias GameOfLife.Cell
  alias GameOfLifeWeb.PageLive.CellComponent

  @grid_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: spawn_cells()
    {:ok, assign(socket, grid_size: @grid_size)}
  end

  @impl true
  def handle_info({:set_alive, row, col, alive?}, socket) do
    send_update(CellComponent, id: "cell-#{row}-#{col}", alive?: alive?)
    {:noreply, socket}
  end

  defp spawn_cells() do
    for row <- 1..@grid_size do
      for col <- 1..@grid_size do
        Cell.start_link(%{lv_pid: self(), row: row, col: col})
      end
    end
  end
end
