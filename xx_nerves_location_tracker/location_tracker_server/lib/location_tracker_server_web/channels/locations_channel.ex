defmodule LocationTrackerServerWeb.LocationsChannel do
  use Phoenix.Channel

  alias LocationTrackerServer.Locations

  def join("locations:sending", _message, socket) do
    {:ok, socket}
  end

  def handle_in("add_point", %{"longitude" => longitude, "latitude" => latitude}, socket)
      when is_float(longitude) and is_float(latitude) do
    {:ok, _point} = Locations.create_point(%{longitude: longitude, latitude: latitude})
    {:reply, :ok, socket}
  end

  def handle_in("add_point", _payload, socket) do
    {:reply, :error, socket}
  end
end
