defmodule Icmp.Socket do
  @moduledoc """
  Opens an ICMP datagram network socket and offers helper functions for sending out ICMP packages.

  Written with the help of https://github.com/hauleth/gen_icmp/blob/master/src/inet_icmp.erl
  """

  @doc "Starts the Socket GenServer"
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc "Sends an ICMP packet to a given IP with a given timeout"
  def send(pid, packet, ip, timeout) do
    GenServer.call(pid, {:send, ip, packet, timeout}, to_timeout(second: timeout + 1))
  end

  @doc "Stops the Socket GenServer"
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Callbacks

  def init(_args) do
    :socket.open(:inet, :dgram, :icmp)
  end

  def handle_call({:send, ip, packet, timeout}, _from, socket) do
    response = do_send(packet, ip, timeout, socket)

    {:reply, response, socket}
  end

  defp do_send(packet, ip, timeout, socket) do
    dest_addr = %{family: :inet, addr: ip}

    {time, result} =
      :timer.tc(fn ->
        :socket.sendto(socket, packet, dest_addr)
        :socket.recvfrom(socket, [], to_timeout(second: timeout))
      end)

    case result do
      {:ok, {_source, reply_packet}} -> {:ok, time, reply_packet}
      error -> error
    end
  end
end
