defmodule LocationTrackerServerWeb.LocationsChannel do
  use Phoenix.Channel

  alias LocationTrackerServer.Locations

  def join("locations:sending", _message, socket) do
    {:ok, socket}
  end

  def handle_in("add_point", %{"latitude" => latitude, "longitude" => longitude}, socket)
      when is_float(longitude) and is_float(latitude) do
    {:ok, _point} = Locations.create_point(%{latitude: latitude, longitude: longitude})
    {:reply, :ok, socket}
  end

  def handle_in("add_point", _payload, socket) do
    {:reply, :error, socket}
  end
end
