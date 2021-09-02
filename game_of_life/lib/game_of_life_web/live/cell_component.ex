defmodule GameOfLifeWeb.PageLive.CellComponent do
  use GameOfLifeWeb, :live_component

  def render(assigns) do
    ~H"""
      <td class={"cell #{ if @alive?, do: 'alive' }"} ></td>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, :alive?, false)}
  end
end
