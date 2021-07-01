defmodule LocationTrackerServerWeb.PageLiveTest do
  use LocationTrackerServerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "LocationTrackerServer"
    assert render(page_live) =~ "LeafletMap"
  end
end
