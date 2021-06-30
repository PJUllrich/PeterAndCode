defmodule LocationTrackerServerWeb.PageLive do
  use LocationTrackerServerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(LocationTrackerServer.PubSub, "location_points")
    {:ok, socket}
  end

  @impl true
  def handle_info({:add_point, longitude, latitude}, socket) do
    {:noreply,
     push_event(socket, "add_point", %{point: %{longitude: longitude, latitude: latitude}})}
  end
end
