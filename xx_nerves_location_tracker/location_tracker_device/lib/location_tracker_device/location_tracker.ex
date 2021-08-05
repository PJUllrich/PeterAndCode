defmodule LocationTrackerDevice.LocationTracker do
  @moduledoc false

  use GenServer

  require Logger

  alias LocationTrackerDevice.SocketClient

  @channel_topic "locations:sending"
  @uart_port "/dev/ttyAMA0"
  @min_location_change_threshold_in_meters 3.0

  @initial_state %{
    latitude: nil,
    longitude: nil,
    gps_enabled: false,
    receiving_gps_data: false
  }

  def get_uart_client() do
    GenServer.call(__MODULE__, :get_uart_client)
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, ws_client} = SocketClient.start_link()
    {:ok, uart_client} = start_uart_link()
    state = Map.merge(%{ws_client: ws_client, uart_client: uart_client}, @initial_state)
    {:ok, state, {:continue, :join_topic}}
  end

  def handle_continue(:join_topic, %{ws_client: ws_client} = state) do
    send(ws_client, {:join, @channel_topic})
    send(self(), :maybe_turn_on_gps)
    {:noreply, state}
  end

  def handle_call(:get_uart_client, _from, %{uart_client: uart_client} = state) do
    {:reply, uart_client, state}
  end

  def handle_info(:maybe_turn_on_gps, %{uart_client: uart_client, gps_enabled: false} = state) do
    Logger.debug("GPS disabled. Trying to enabled it...")
    WaveshareHat.GNSS.set_on_or_off(uart_client, 1)
    # Check again after 1 second whether GPS is turned on
    Process.send_after(self(), :maybe_turn_on_gps, 1_000)
    {:noreply, state}
  end

  def handle_info(:maybe_turn_on_gps, %{gps_enabled: true} = state) do
    {:noreply, state}
  end

  def handle_info({:add_point, latitude, longitude}, state) do
    Logger.info("Trying to add point: #{latitude}, #{longitude}")
    add_point(latitude, longitude, state)

    {:noreply, state}
  end

  def handle_info({:nerves_uart, _uart_port, "OK"}, %{uart_client: uart_client} = state) do
    state =
      cond do
        not state.gps_enabled ->
          WaveshareHat.GNSS.set_send_gps_data_to_uart(uart_client, 1)
          %{state | gps_enabled: true}

        state.gps_enabled && not state.receiving_gps_data ->
          %{state | receiving_gps_data: true}

        true ->
          state
      end

    {:noreply, state}
  end

  def handle_info({:nerves_uart, _uart_port, "$GNGGA," <> gps_data}, state) do
    data = String.split(gps_data, ",")

    # Check if data contains coordinates.
    # If not, GPS is still trying to get a fix.
    state =
      if Enum.at(data, 1) != "" do
        latitude = data |> Enum.at(1) |> String.to_float() |> Kernel./(100)
        longitude = data |> Enum.at(3) |> String.to_float() |> Kernel./(100)
        distance = calc_distance(latitude, longitude, state)

        Logger.debug("Position: #{latitude}, #{longitude}. Distance change: #{distance} Meters")

        if distance == :infinity || distance > @min_location_change_threshold_in_meters do
          Logger.debug("Location change significant. Addinp point: #{latitude}, #{longitude}")
          add_point(latitude, longitude, state)
          %{state | latitude: latitude, longitude: longitude}
        else
          state
        end
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(event, state) do
    Logger.debug(inspect(event))
    {:noreply, state}
  end

  defp start_uart_link() do
    {:ok, pid} = Circuits.UART.start_link()
    :ok = Circuits.UART.open(pid, @uart_port, speed: 115_200)
    :ok = Circuits.UART.configure(pid, framing: {Circuits.UART.Framing.Line, separator: "\r\n"})
    {:ok, pid}
  end

  defp add_point(latitude, longitude, %{ws_client: ws_client} = _state) do
    send(
      ws_client,
      {:send, @channel_topic, "add_point",
       %{
         "latitude" => latitude,
         "longitude" => longitude
       }}
    )
  end

  defp calc_distance(_new_lat, _new_lon, %{latitude: nil, longitude: nil} = _state) do
    :infinity
  end

  # Calculation taken from: https://www.movable-type.co.uk/scripts/latlong.html
  defp calc_distance(lat2, lon2, %{latitude: lat1, longitude: lon1} = _state) do
    phi_1 = lat1 * (:math.pi() / 180)
    phi_2 = lat2 * (:math.pi() / 180)
    delta_phi = (lat2 - lat1) * (:math.pi() / 180)
    delta_lambda = (lon2 - lon1) * (:math.pi() / 180)

    a =
      :math.sin(delta_phi / 2) * :math.sin(delta_phi / 2) +
        :math.cos(phi_1) * :math.cos(phi_2) * :math.sin(delta_lambda / 2) *
          :math.sin(delta_lambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    6_371_000 * c
  end
end
