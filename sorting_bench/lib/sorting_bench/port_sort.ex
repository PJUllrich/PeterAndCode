defmodule SortingBench.PortSort do
  @moduledoc """
  Sorting via a Rust Port process communicating over stdin/stdout pipes.

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

  def start do
    executable =
      Path.join([__DIR__, "..", "..", "port_sort", "target", "release", "port_sort"])
      |> Path.expand()

    unless File.exists?(executable) do
      raise """
      Port sort binary not found at #{executable}.
      Build it with: cd port_sort && cargo build --release
      """
    end

    Port.open({:spawn_executable, executable}, [
      :binary,
      {:packet, 4}
    ])
  end

  def sort(port, binary) when is_binary(binary) do
    Port.command(port, binary)

    receive do
      {^port, {:data, sorted}} -> sorted
    after
      30_000 -> raise "Port sort timeout"
    end
  end

  def stop(port) do
    Port.close(port)
  end
end
