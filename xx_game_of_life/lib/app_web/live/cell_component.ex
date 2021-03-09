defmodule AppWeb.GameOfLive.CellComponent do
  use AppWeb, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <td class=<%= if @alive, do: "alive" %>></td>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :alive, false)}
  end
end
