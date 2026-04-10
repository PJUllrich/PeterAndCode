defmodule SortingBench.PortSort do
  @moduledoc """
  Sorting via a Rust Port process communicating over stdin/stdout pipes.

  Wraps the port in a GenServer so that any process (including Benchee's
  Task workers) can call `sort/2` — the GenServer owns the port and
  relays responses.

  Copy cost profile (per call):
    1. BEAM serializes the binary + 4-byte length header
    2. Kernel copies data into the pipe buffer (write syscall)
    3. Rust reads from stdin (read syscall + kernel copy)
    4. Rust sorts in-place
    5. Rust writes sorted data to stdout (write syscall + kernel copy)
    6. BEAM reads from the pipe (read syscall + kernel copy)

  This is the classic Unix pipe approach. Copy cost sits between
  NIF (in-process, near-zero) and C Node (TCP + distribution protocol).
  Each direction involves one kernel buffer copy via the pipe.
  """

  use GenServer

  # -- Public API --------------------------------------------------------------

  def start do
    {:ok, pid} = GenServer.start(__MODULE__, [])
    pid
  end

  def sort(pid, binary) when is_binary(binary) do
    GenServer.call(pid, {:sort, binary}, 30_000)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # -- GenServer callbacks -----------------------------------------------------

  @impl true
  def init([]) do
    executable =
      Path.join([__DIR__, "..", "..", "port_sort", "target", "release", "port_sort"])
      |> Path.expand()

    unless File.exists?(executable) do
      raise """
      Port sort binary not found at #{executable}.
      Build it with: cd port_sort && cargo build --release
      """
    end

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        {:packet, 4}
      ])

    {:ok, %{port: port, caller: nil}}
  end

  @impl true
  def handle_call({:sort, binary}, from, %{port: port} = state) do
    Port.command(port, binary)
    {:noreply, %{state | caller: from}}
  end

  @impl true
  def handle_info({port, {:data, sorted}}, %{port: port, caller: caller} = state) do
    GenServer.reply(caller, sorted)
    {:noreply, %{state | caller: nil}}
  end

  @impl true
  def terminate(_reason, %{port: port}) do
    Port.close(port)
  end
end
