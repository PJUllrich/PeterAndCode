defmodule Traceroute.Test do
  @moduledoc """
  Tests whether two open ICMP sockets receive the same packets or not.
  """

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def send_icmp() do
    {:ok, socket} = :socket.open(:inet, :dgram, :icmp)

    ip = Traceroute.Utils.get_ip("google.com")
    dest_addr = %{family: :inet, addr: ip}

    # Echo Request
    type = 8
    code = 0
    id = :rand.uniform(65535)
    sequence = 1
    payload = "ping"

    datagram = Traceroute.Protocols.Icmp.encode_datagram(type, code, id, sequence, payload)

    # :ok = :socket.setopt(socket, {:ip, :ttl}, 3)
    :socket.sendto(socket, datagram, dest_addr)

    case :socket.recvfrom(socket, [], 5000) do
      {:ok, {_source, data}} ->
        IO.inspect(data, label: "Server responded!")

      {:error, :timeout} ->
        IO.inspect("No response. Timeout")
    end

    :socket.close(socket)
  end

  def send_udp() do
    {:ok, socket} = :socket.open(:inet, :dgram, :udp)

    # ip = Traceroute.Utils.get_ip("google.com")
    dest_addr = %{family: :inet, addr: {8, 8, 8, 8}, port: 33434}

    payload = "probe"

    :socket.sendto(socket, payload, dest_addr)

    # case :socket.recvfrom(socket, [], 5000) do
    #   {:ok, {_source, data}} ->
    #     IO.inspect(data, label: "Server responded!")

    #   {:error, :timeout} ->
    #     IO.inspect("No response. Timeout")
    # end

    :socket.close(socket)
  end

  # Callbacks

  def init(args) do
    protocol = Keyword.get(args, :protocol, :icmp)
    {:ok, socket} = :socket.open(:inet, :dgram, protocol)
    send(self(), :start_listen)
    {:ok, socket}
  end

  def handle_info(:start_listen, socket) do
    IO.inspect("Start listening on #{owner(socket)}")
    listen_loop(socket)
  end

  defp listen_loop(socket) do
    case :socket.recvfrom(socket) do
      {:ok, {source, data}} ->
        IO.inspect({source, data, owner(socket)}, label: "Received ICMP packet")
        listen_loop(socket)

      {:error, reason} ->
        IO.inspect({reason, owner(socket)}, label: "Error receiving packet")
        listen_loop(socket)
    end
  end

  defp owner(socket) do
    %{owner: owner} = :socket.info(socket)
    inspect(owner)
  end
end
