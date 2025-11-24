defmodule Traceroute.Icmp do
  @moduledoc """
  Opens an ICMP datagram network socket and sends out ICMP packets through it.

  Written with the help of https://github.com/hauleth/gen_icmp/blob/master/src/inet_icmp.erl
  """

  use GenServer

  @doc "Starts the Socket GenServer"
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc "Sends an ICMP packet to a given IP with a given timeout"
  def send(pid, packet, ip, ttl, timeout) do
    GenServer.call(pid, {:send, ip, packet, ttl, timeout}, to_timeout(second: timeout + 1))
  end

  @doc "Stops the Socket GenServer"
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Callbacks

  @impl GenServer
  def init(_args) do
    :socket.open(:inet, :dgram, :icmp)
  end

  @impl GenServer
  def handle_call({:send, ip, packet, ttl, timeout}, _from, socket) do
    response = do_send(ip, packet, ttl, timeout, socket)

    {:reply, response, socket}
  end

  @impl GenServer
  def terminate(_reason, socket) do
    :socket.close(socket)
    :ok
  end

  defp do_send(ip, packet, ttl, timeout, socket) do
    dest_addr = %{family: :inet, addr: ip}

    :ok = :socket.setopt(socket, {:ip, :ttl}, ttl)

    {time, result} =
      :timer.tc(fn ->
        :socket.sendto(socket, packet, dest_addr)
        :socket.recvfrom(socket, [], to_timeout(second: timeout)) |> IO.inspect()
      end)

    with {:ok, {_source, reply_packet}} <- result do
      {:ok, time, reply_packet}
    end
  end
end
