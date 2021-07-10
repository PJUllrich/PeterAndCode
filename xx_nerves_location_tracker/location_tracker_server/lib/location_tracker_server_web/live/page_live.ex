defmodule LocationTrackerServerWeb.PageLive do
  use LocationTrackerServerWeb, :live_view

  alias LocationTrackerServer.Locations

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LocationTrackerServer.PubSub, "location_points")
    end

    points = Locations.list_location_points()
    {:ok, push_points(points, socket)}
  end

  @impl true
  def handle_info({:add_point, point}, socket) do
    {:noreply, push_points(point, socket)}
  end

  defp push_points(point, socket) when is_struct(point) do
    push_points([point], socket)
  end

  defp push_points(points, socket) when is_list(points) do
    points = Enum.map(points, &Map.take(&1, [:latitude, :longitude]))
    push_event(socket, "add_points", %{points: points})
  end
end
