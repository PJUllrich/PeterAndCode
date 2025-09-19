defmodule Tracker.ADSBReceiver do
  use GenServer

  require Logger

  alias Tracker.ReadsbManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Callbacks

  @impl GenServer
  def init(_opts) do
    %{json_port: json_port} = ReadsbManager.get_state()

    case connect_with_retry(json_port, 15) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        Logger.error("Failed to connect after 15 attempts: #{reason}")
        exit(:connection_failed)
    end
  end

  @impl GenServer
  def handle_info({:tcp, _socket, data}, state) do
    # Parse JSON messages
    data
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.each(&process_message/1)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Connection closed, attempting reconnect...")
    # Add reconnection logic here
    {:noreply, state}
  end

  defp connect_with_retry(_port, 0) do
    {:error, :max_retries_exceeded}
  end

  defp connect_with_retry(port, attempts_left) do
    case :gen_tcp.connect(~c"localhost", port, [:binary, active: true]) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, _reason} ->
        Process.sleep(1000)
        connect_with_retry(port, attempts_left - 1)
    end
  end

  defp process_message(json_string) do
    case Jason.decode(json_string) do
      {:ok, message} ->
        Logger.info("Received ADS-B message: #{inspect(message)}")

      # Process your message here
      {:error, reason} ->
        Logger.warning("Failed to decode JSON: #{reason}")
    end
  end
end
