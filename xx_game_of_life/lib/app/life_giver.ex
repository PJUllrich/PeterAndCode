defmodule LifeGiver do
  use GenServer

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, :initial_state}
  end

  def handle_info({:spawn_cell, x: x, y: y}, state) do
    spawn_cell(x: x, y: y)
    {:noreply, state}
  end

  def spawn_cell(x: x, y: y) do
    CellSupervisor.start_child(x: x, y: y)
  end
end
