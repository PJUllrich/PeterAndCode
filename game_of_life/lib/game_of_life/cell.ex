defmodule GameOfLife.Cell do
  use GenServer

  def start_link(init_args) do
    alive? = Map.get(init_args, :alive?, Enum.random([true, false]))
    args = Map.merge(init_args, %{alive?: alive?})
    GenServer.start_link(__MODULE__, args)
  end

  def init(%{alive?: alive?} = args) do
    if alive?, do: set_alive(args)
    {:ok, args}
  end

  defp set_alive(%{lv_pid: lv_pid, row: row, col: col, alive?: alive?}) do
    send(lv_pid, {:set_alive, row, col, alive?})
  end
end
