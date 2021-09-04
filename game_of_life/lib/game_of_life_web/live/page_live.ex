defmodule GameOfLifeWeb.PageLive do
  use GameOfLifeWeb, :live_view

  alias GameOfLife.Cell

  @grid_size 225
  @update_frequency_in_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :spawn_cells)
    grid = time(&setup_grid/0)

    {:ok,
     assign(socket,
       grid: grid,
       staging_grid: grid,
       grid_size: @grid_size,
       cells: [],
       started: false
     )}
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
  def handle_info(:spawn_cells, socket) do
    cells = time(&spawn_cells/0)
    {:noreply, assign(socket, cells: cells)}
  end

  @impl true
  def handle_info(
        {:set_alive, row, col, alive?},
        %{assigns: %{staging_grid: staging_grid}} = socket
      ) do
    staging_grid = Map.put(staging_grid, {row, col}, alive?)
    {:noreply, assign(socket, staging_grid: staging_grid)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{started: started, staging_grid: staging_grid}} = socket) do
    if started, do: notify_cells_and_schedule_next_step(:tick, :tock, socket)
    socket = if started, do: set_grid(staging_grid, socket), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tock, socket) do
    notify_cells_and_schedule_next_step(:tock, :tick, socket)
    {:noreply, socket}
  end

  defp setup_grid() do
    grid = for row <- 1..@grid_size, col <- 1..@grid_size, do: {{row, col}, false}
    Map.new(grid)
  end

  defp spawn_cells() do
    own_pid = self()

    for row <- 1..@grid_size, col <- 1..@grid_size do
      {:ok, pid} =
        Cell.start_link(%{lv_pid: own_pid, row: row, col: col, boundaries: [1, @grid_size]})

      pid
    end
    |> List.flatten()
  end

  defp notify_cells_and_schedule_next_step(
         current_step,
         next_step,
         %{assigns: %{cells: cells}}
       ) do
    Enum.each(cells, &send(&1, current_step))
    Process.send_after(self(), next_step, @update_frequency_in_ms)
  end

  defp set_grid(new_grid, socket), do: assign(socket, grid: new_grid)

  defp time(fun) do
    info = Function.info(fun)
    fun_name = Keyword.get(info, :name)
    t0 = now()
    IO.inspect("Running #{fun_name}", label: t0)

    res = fun.()

    t1 = now()
    IO.inspect("Ran #{fun_name}", label: t1)
    IO.inspect("Running #{fun_name} took #{t1 - t0}ms", label: t1)

    res
  end

  defp now(), do: DateTime.to_unix(DateTime.utc_now(), :millisecond)
end
