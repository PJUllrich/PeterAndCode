defmodule LocationTrackerDevice.SocketClient do
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient

  @channel_topic "locations:sending"

  def start_link() do
    url = Application.get_env(:location_tracker_device, :server_url)

    GenSocketClient.start_link(
      __MODULE__,
      Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
      "#{url}/socket/websocket"
    )
  end

  def init(url) do
    token = Application.get_env(:location_tracker_device, :channel_token)
    {:connect, url, [token: token], %{}}
  end

  def handle_info(:join, transport, state) do
    Logger.info("joining the topic #{@channel_topic}")

    case GenSocketClient.join(transport, @channel_topic) do
      {:error, reason} ->
        Logger.error("error joining the topic #{@channel_topic}: #{inspect(reason)}")
        Process.send_after(self(), :join, :timer.seconds(1))

      {:ok, _ref} ->
        :ok
    end

    {:ok, state}
  end

  def handle_info({:send, topic, event, payload}, transport, state) do
    GenSocketClient.push(transport, topic, event, payload)
    |> case do
      {:ok, _ref} ->
        Logger.info("Event published successfully on #{topic} with #{inspect(payload)}")

      {:error, error} ->
        Logger.error("Event publishing failed with error #{error}")
    end

    {:ok, state}
  end

  def handle_info(:connect, _transport, state) do
    Logger.info("connecting")
    {:connect, state}
  end

  def handle_info(message, _transport, state) do
    Logger.warn("Unhandled message #{inspect(message)}")
    {:ok, state}
  end

  def handle_connected(_transport, state) do
    Logger.info("connected")
    send(self(), :join)
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.error("disconnected: #{inspect(reason)}")
    Process.send_after(self(), :connect, :timer.seconds(1))
    {:ok, state}
  end

  def handle_joined(topic, _payload, _transport, state) do
    Logger.info("joined the topic #{topic}")

    {:ok, state}
  end

  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("join error on the topic #{topic}: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("disconnected from the topic #{topic}: #{inspect(payload)}")
    Process.send_after(self(), {:join, topic}, :timer.seconds(1))
    {:ok, state}
  end

  def handle_message(topic, event, payload, _transport, state) do
    Logger.warn("message on topic #{topic}: #{event} #{inspect(payload)}")
    {:ok, state}
  end

  def handle_reply(topic, _ref, payload, _transport, state) do
    Logger.info("reply on topic #{topic}: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_call(message, _from, _transport, state) do
    Logger.warn("Did not expect to receive call with message: #{inspect(message)}")
    {:reply, {:error, :unexpected_message}, state}
  end

  def terminate(reason, _state) do
    Logger.info("Terminating and cleaning up state. Reason for termination: #{reason}")
  end
end
