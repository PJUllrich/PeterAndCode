defmodule Tracker.ReadsbManager do
  @moduledoc """
  GenServer that manages the readsb CLI process and parses ADS-B data.

  This module spawns and monitors the readsb process, captures its output,
  and parses the ADS-B messages for aircraft tracking.
  """

  use GenServer
  require Logger

  @default_json_port 4001

  @default_readsb_args [
    "--quiet",
    "--device-type=rtlsdr",
    "--net",
    "--net-json-port=#{@default_json_port}",
    "--net-ro-size=8192"
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    config = Application.get_env(:tracker, :readsb, [])

    readsb_path = Keyword.get(opts, :readsb_path) || Keyword.get(config, :readsb_path, "readsb")

    readsb_args =
      Keyword.get(opts, :readsb_args) || Keyword.get(config, :readsb_args, @default_readsb_args)

    json_port = Keyword.get(opts, :json_port, @default_json_port)

    readsb_args =
      Enum.map(readsb_args, fn
        "--net-json-port" <> _rest -> "--net-json-port=#{json_port}"
        line -> line
      end)

    reference_lat = Keyword.get(config, :reference_lat)
    reference_lon = Keyword.get(config, :reference_lon)
    max_aircraft_age = Keyword.get(config, :max_aircraft_age, 60)

    state = %{
      port: nil,
      os_pid: nil,
      json_port: json_port,
      readsb_path: readsb_path,
      readsb_args: readsb_args,
      reference_lat: reference_lat,
      reference_lon: reference_lon,
      max_aircraft_age: max_aircraft_age
    }

    state = start_readsb(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("ReadSB process exited with status: #{status}")
    # Restart after 5 seconds
    Process.send_after(self(), :retry_start, 5000)
    {:noreply, %{state | port: nil}}
  end

  @impl GenServer
  def handle_info(:retry_start, state) do
    {:noreply, start_readsb(state)}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{port: nil}), do: :ok

  @impl GenServer
  def terminate(_reason, %{port: port, os_pid: os_pid}) do
    # 1. Try graceful port close
    Port.close(port)

    # 2. Send SIGTERM
    System.cmd("kill", ["-TERM", "#{os_pid}"], stderr_to_stdout: true)

    # 3. Wait briefly
    Process.sleep(500)

    # 4. Force kill if needed
    case System.cmd("ps", ["-p", "#{os_pid}"], stderr_to_stdout: true) do
      {_, 0} -> System.cmd("kill", ["-KILL", "#{os_pid}"], stderr_to_stdout: true)
      _ -> :ok
    end

    :ok
  end

  # Private Functions

  defp start_readsb(state) do
    case start_readsb_process(state) do
      {:ok, port} ->
        Logger.info("ReadSB process started successfully")
        {:os_pid, os_pid} = Port.info(port, :os_pid)
        %{state | port: port, os_pid: os_pid}

      {:error, reason} ->
        Logger.error("Failed to start ReadSB process: #{inspect(reason)}")
        # Retry after 5 seconds
        Process.send_after(self(), :retry_start, 5000)
        state
    end
  end

  defp start_readsb_process(state) do
    try do
      port =
        Port.open({:spawn_executable, System.find_executable(state.readsb_path)}, [
          :binary,
          :exit_status,
          {:args, state.readsb_args}
        ])

      {:ok, port}
    rescue
      e ->
        Logger.error("Could not start readsb: #{inspect(e)}")
        {:error, e}
    end
  end
end
