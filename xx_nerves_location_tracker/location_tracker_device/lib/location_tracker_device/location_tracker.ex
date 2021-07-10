defmodule LocationTrackerDevice.LocationTracker do
  @moduledoc false

  use GenServer

  require Logger

  alias LocationTrackerDevice.SocketClient

  @channel_topic "locations:sending"
  @uart_port "/dev/ttyAMA0"

  def get_uart_client() do
    GenServer.call(__MODULE__, :get_uart_client)
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, ws_client} = SocketClient.start_link()
    {:ok, uart_client} = start_uart_link()
    {:ok, %{ws_client: ws_client, uart_client: uart_client}, {:continue, :join_topic}}
  end

  @impl true
  def handle_continue(:join_topic, %{ws_client: ws_client, uart_client: uart_client} = state) do
    send(ws_client, {:join, @channel_topic})
    WaveshareHat.GNSS.set_on_or_off(uart_client, 1)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_uart_client, _from, %{uart_client: uart_client} = state) do
    {:reply, uart_client, state}
  end

  @impl true
  def handle_info({:add_point, latitude, longitude}, state) do
    Logger.info("Trying to add point: #{latitude}, #{longitude}")
    add_point(latitude, longitude, state)

    {:noreply, state}
  end

  def handle_info({:nerves_uart, _uart_port, "$GNGGA," <> gps_data}, state) do
    data = String.split(gps_data)

    # Check if data contains coordinates.
    # If not, GPS is still trying to get a fix.
    if Enum.at(data, 1) != "" do
      latitude = data |> Enum.at(1) |> String.to_float() |> Kernel./(100)
      longitude = data |> Enum.at(3) |> String.to_float() |> Kernel./(100)
      Logger.debug("Position: #{latitude}, #{longitude}")
    end

    {:noreply, state}
  end

  def handle_info(event, state) do
    Logger.debug(inspect(event))
    {:noreply, state}
  end

  defp start_uart_link() do
    {:ok, pid} = Nerves.UART.start_link()
    :ok = Nerves.UART.open(pid, @uart_port, speed: 115_200)
    :ok = Nerves.UART.configure(pid, framing: {Nerves.UART.Framing.Line, separator: "\r\n"})
    {:ok, pid}
  end

  defp add_point(longitude, latitude, %{ws_client: ws_client} = _state) do
    send(
      ws_client,
      {:send, @channel_topic, "add_point",
       %{
         "latitude" => latitude,
         "longitude" => longitude
       }}
    )
  end
end
