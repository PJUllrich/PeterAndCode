defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  @grid_size 10

  @impl Mix.Task
  def run(_args) do
    grid = setup_grid()

    Benchee.run(
      %{
        "update_grid" => fn {row, col, alive?} ->
          update_grid(grid, row, col, alive?)
        end
      },
      time: 10,
      before_each: fn _ ->
        row = Enum.random(1..@grid_size)
        col = Enum.random(1..@grid_size)
        alive? = Enum.random([true, false])
        {row, col, alive?}
      end
    )
  end

  defp setup_grid() do
    grid = for row <- 1..@grid_size, col <- 1..@grid_size, do: {{row, col}, false}
    Map.new(grid)
  end

  def update_grid(grid, row, col, alive?) do
    Map.put(grid, {row, col}, alive?)
  end
end
