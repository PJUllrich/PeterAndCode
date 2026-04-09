defmodule SortingBench.CNodeSort do
  @moduledoc """
  Wraps the C Node sorter.

  The C Node is a standalone C program that connects to the BEAM via the
  distributed Erlang protocol. It receives packed-i64 binaries, sorts them
  with libc qsort, and sends the result back.

  Copy cost profile (per call):
    1. BEAM serializes the binary into the distribution protocol format
    2. Sends over TCP loopback to the C Node
    3. C Node deserializes, malloc's, and sorts
    4. C Node serializes the sorted binary and sends it back over TCP
    5. BEAM deserializes the result

  This gives the HIGHEST copy cost of all approaches but demonstrates
  near-native C sorting speed for the actual computation.
  """

  @c_node_alive "sort_node"

  def start do
    ensure_distributed!()

    executable = Path.join([__DIR__, "..", "..", "c_node", "sort_node"]) |> Path.expand()

    unless File.exists?(executable) do
      raise "C Node binary not found at #{executable}. Run `make -C c_node` first."
    end

    beam_node = Atom.to_string(node())
    cookie = Atom.to_string(Node.get_cookie())

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :stderr_to_stdout,
        args: [@c_node_alive, cookie, beam_node]
      ])

    # Wait for the C Node to appear in our connected nodes
    c_node_name = c_node_name()
    wait_for_connection(c_node_name, 50)

    {port, c_node_name}
  end

  def sort(c_node_name, binary) when is_binary(binary) do
    send({:any, c_node_name}, {self(), {:sort, binary}})

    receive do
      {:sorted, result} -> result
    after
      30_000 -> raise "C Node sort timeout"
    end
  end

  @doc "Reference: generate + sort entirely in the C Node (zero data transfer)"
  def generate_and_sort(c_node_name, num_elements) do
    send({:any, c_node_name}, {self(), {:generate_and_sort, num_elements}})

    receive do
      :ok -> :ok
    after
      30_000 -> raise "C Node generate_and_sort timeout"
    end
  end

  def stop(port, c_node_name) do
    send({:any, c_node_name}, {self(), :stop})
    Process.sleep(100)
    Port.close(port)
  end

  # -- private ----------------------------------------------------------------

  defp ensure_distributed! do
    unless Node.alive?() do
      {:ok, _} = Node.start(:bench, :shortnames)
      Node.set_cookie(:sorting_bench)
    end
  end

  defp c_node_name do
    {_, hostname} = :inet.gethostname()
    :"#{@c_node_alive}@#{hostname}"
  end

  defp wait_for_connection(name, 0) do
    raise "C Node #{name} did not connect. Connected nodes: #{inspect(Node.list(:hidden))}"
  end

  defp wait_for_connection(name, retries) do
    if name in Node.list(:hidden) do
      :ok
    else
      Process.sleep(100)
      wait_for_connection(name, retries - 1)
    end
  end
end
