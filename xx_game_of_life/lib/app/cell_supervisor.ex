defmodule CellSupervisor do
  use DynamicSupervisor

  def start_link(lv_pid) do
    DynamicSupervisor.start_link(__MODULE__, lv_pid: lv_pid)
  end

  def start_child(supervisor_pid, pid_and_coordinates) do
    child_spec = {Cell, pid_and_coordinates}

    DynamicSupervisor.start_child(supervisor_pid, child_spec)
  end

  def init([_init_args]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
