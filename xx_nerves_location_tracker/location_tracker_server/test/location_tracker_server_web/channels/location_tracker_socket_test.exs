defmodule LocationTrackerSocketTest do
  use LocationTrackerServerWeb.ChannelCase

  alias LocationTrackerServerWeb.LocationTrackerSocket
  alias LocationTrackerServerWeb.LocationsChannel
  alias LocationTrackerServer.Locations

  setup do
    {:ok, _, socket} =
      LocationTrackerSocket
      |> socket()
      |> subscribe_and_join(LocationsChannel, "locations:sending")

    %{socket: socket}
  end

  test "cannot connect with the socket if an invalid token was given" do
    assert :error = connect(LocationTrackerSocket, %{"token" => "foo"})
    assert {:ok, _socket} = connect(LocationTrackerSocket, %{"token" => "channel_token"})
  end

  test "sending a location over the channel stores it in the Database", %{socket: socket} do
    ref = push(socket, "add_point", %{"longitude" => 10.0, "latitude" => 5.73})
    assert_reply ref, :ok

    assert [point] = Locations.list_location_points()
    assert point.longitude == 10.0
    assert point.latitude == 5.73
  end

  test "sending a location with invalid coordinates to the channel returns an error", %{
    socket: socket
  } do
    ref = push(socket, "add_point", %{"longitude" => 10, "latitude" => "bar"})
    assert_reply ref, :error
  end
end
