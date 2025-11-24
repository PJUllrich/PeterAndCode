defmodule Traceroute.Udp do
  @moduledoc """
  Opens a UDP socket for sending probe packets and an ICMP socket for receiving responses.

  This implements the UDP-based traceroute approach where:
  1. UDP packets are sent to high-numbered ports with increasing TTL values
  2. ICMP "Time Exceeded" or "Port Unreachable" messages are received on a separate ICMP socket
  3. The UDP socket triggers ICMP errors, but we read them from the ICMP socket

  This is how traditional traceroute works - it uses separate sockets for sending and receiving.
  """

  use GenServer

  @default_dest_port 33434

  @doc "Starts the Socket GenServer"
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc "Sends a UDP probe packet to a given IP with a given TTL and timeout."
  def send(pid, packet, ip, ttl, timeout) do
    GenServer.call(pid, {:send, ip, packet, ttl, timeout}, to_timeout(second: timeout + 1))
  end

  @doc "Stops the Socket GenServer"
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    dest_port = Keyword.get(args, :dest_port, @default_dest_port)

    # Open both UDP (for sending) and ICMP (for receiving) sockets
    with {:ok, udp_socket} <- :socket.open(:inet, :dgram, :udp),
         {:ok, icmp_socket} <- :socket.open(:inet, :dgram, :icmp) do
      state = %{
        udp_socket: udp_socket,
        icmp_socket: icmp_socket,
        dest_port: dest_port
      }

      {:ok, state}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:send, ip, packet, ttl, timeout}, _from, state) do
    response = do_send(ip, packet, ttl, timeout, state)

    {:reply, response, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    :socket.close(state.udp_socket)
    :socket.close(state.icmp_socket)
    :ok
  end

  defp do_send(ip, packet, ttl, timeout, state) do
    dest_addr = %{family: :inet, addr: ip, port: state.dest_port}

    :ok = :socket.setopt(state.udp_socket, {:ip, :ttl}, ttl)

    {time, result} =
      :timer.tc(fn ->
        :socket.sendto(state.udp_socket, packet, dest_addr)
        :socket.recvfrom(state.icmp_socket, [], to_timeout(second: timeout))
      end)

    with {:ok, {_source, reply_packet}} <- result do
      {:ok, time, reply_packet}
    end
  end
end
