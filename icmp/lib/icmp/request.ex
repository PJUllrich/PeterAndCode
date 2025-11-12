defmodule Icmp.Socket do
  @moduledoc """
  Starts a datagram UNIX socket and offers helper functions for sending out ICMP packages.
  """

  import Bitwise

  @doc "Starts the Socket GenServer"
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def ping(pid, ip, payload, timeout \\ 15) do
    GenServer.call(pid, {:ping, payload, ip, timeout}, to_timeout(second: timeout + 1))
  end

  @doc "Stops the Socket GenServer"
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Callbacks

  def init(_args) do
    :socket.open(:inet, :dgram, :icmp)
  end

  def handle_call({:ping, ip, payload, timeout}, _from, socket) do
    # Echo Request
    type = 8
    # Echo Reply
    code = 0
    id = :rand.uniform(65535)
    sequence = 1

    packet = encode(type, code, id, sequence, payload)

    dest_addr = %{family: :inet, addr: ip}
    :socket.sendto(socket, packet, dest_addr)

    result =
      with {:ok, {_source, reply_packet}} <-
             :socket.recvfrom(socket, [], to_timeout(second: timeout)) do
        decode(reply_packet, id, sequence)
      end

    {:reply, result, socket}
  end

  defp encode(type, code, id, sequence, payload) do
    header = <<type, code, 0::16, id::16, sequence::16>>

    checksum = checksum(header <> payload)

    <<type::8, code::8, checksum::16, id::16, sequence::16, payload::bytes>>
  end

  defp decode(packet, id, sequence) do
    nil
  end

  def checksum(data), do: checksum(data, 0)

  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  # Pad the data if it's not divisable by 16 bits
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)

  defp checksum(<<>>, sum) do
    <<left::16, right::16>> = <<sum::32>>
    <<bnot(left + right)::big-integer-size(16)>>
  end
end
