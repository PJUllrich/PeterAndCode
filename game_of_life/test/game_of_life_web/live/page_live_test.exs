defmodule GameOfLifeWeb.PageLiveTest do
  use GameOfLifeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag :wip
  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Welcome to Phoenix!"
    assert render(page_live) =~ "Welcome to Phoenix!"
  end

  test "toggles a cell alive? state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "td[data-phx-component=1]")

    send(view.pid, {:set_alive, 1, 1, true})
    :timer.sleep(1)
    assert has_element?(view, "td[data-phx-component=1][class='cell alive']")

    send(view.pid, {:set_alive, 1, 1, false})
    :timer.sleep(1)
    refute has_element?(view, "td[data-phx-component=1][class='cell alive']")
  end

  @tag :wip
  test "sends a tick message to all cells when 'start' is pressed", %{conn: _conn} do
    assert true
  end
end
