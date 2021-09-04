defmodule GameOfLifeWeb.PageLiveTest do
  use GameOfLifeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "toggles a cell alive? state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "td[id=cell-1-1]")

    send(view.pid, {:set_alive, 1, 1, true})
    :timer.sleep(1)
    assert has_element?(view, "td[id=cell-1-1][class='cell alive']")

    send(view.pid, {:set_alive, 1, 1, false})
    :timer.sleep(1)
    refute has_element?(view, "td[id=cell-1-1][class='cell alive']")
  end

  @tag :wip
  test "sends a tick message to all cells when 'start' is pressed", %{conn: _conn} do
    assert true
  end
end
