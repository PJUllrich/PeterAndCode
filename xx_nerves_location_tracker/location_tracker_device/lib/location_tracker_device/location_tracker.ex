defmodule LocationTrackerDevice.LocationTracker do
  use GenServer

  require Logger

  alias LocationTrackerDevice.SocketClient

  @channel_topic "locations:sending"

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, ws_client} = SocketClient.start_link()
    {:ok, %{ws_client: ws_client}, {:continue, :join_topic}}
  end

  def handle_continue(:join_topic, %{ws_client: ws_client} = state) do
    send(ws_client, {:join, @channel_topic})
    {:noreply, state}
  end

  def handle_info({:add_point, longitude, latitude}, %{ws_client: ws_client} = state) do
    Logger.info("Trying to add point: #{longitude}, #{latitude}")

    send(
      ws_client,
      {:send, @channel_topic, "add_point",
       %{
         "longitude" => longitude,
         "latitude" => latitude
       }}
    )

    {:noreply, state}
  end
end
