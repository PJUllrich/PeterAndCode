defmodule Icmp.Socket do
  @moduledoc """
  Starts a datagram UNIX socket and offers helper functions for sending out ICMP packages.
  """

  import Bitwise

  @doc "Starts the Socket GenServer"
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def decode_domain(domain) when is_binary(domain) do
    {:ok, {:hostent, _, _, :inet, 4, [ip | _]}} = :inet.gethostbyname(String.to_charlist(domain))
    ip
  end

  def ping(pid, ip, payload, timeout \\ 15) do
    GenServer.call(pid, {:ping, ip, payload, timeout}, to_timeout(second: timeout + 1))
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

    <<type::8, code::8, checksum::binary-size(2), id::16, sequence::16, payload::binary>>
  end

  # The IPv4 header of the ICMP response packet looks like this:
  #
  # 0                   1                   2                   3
  # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |Version|  IHL  |Type  of Service|          Total Length       |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |          Identification       |Flags|     Fragment Offset   |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # | Time to Live  |   Protocol    |    Header Checksum          |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                         Source Address                      |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                      Destination Address                    |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |     Type      |   Code        |         Checksum            |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  #
  # IHL: Internet Header Length
  #
  # This is an IPv4 Header: https://en.wikipedia.org/wiki/IPv4
  # Taken from: https://book.huihoo.com/iptables-tutorial/x1078.htm
  defp decode(packet, _id, _sequence) do
    <<ihl_version::4, ihl::4, tos::8, total_length::16, line_2::bytes>> = packet
    <<identification::16, flags::3, offset::13, line_3::bytes>> = line_2
    <<ttl::8, protocol::8, header_checksum::16, line_4::bytes>> = line_3
    <<source_addr::32, line_5::bytes>> = line_4
    <<destination_addr::32, line_6::bytes>> = line_5
    <<type::8, code::8, checksum::16, payload::bytes>> = line_6

    data = parse_payload(type, code, payload)

    %{
      ihl_version: ihl_version,
      ihl: ihl,
      tos: tos,
      total_length: total_length,
      identification: identification,
      flags: flags,
      offset: offset,
      ttl: ttl,
      protocol: protocol,
      header_checksum: header_checksum,
      source_addr: ip_tuple(source_addr),
      destination_addr: ip_tuple(destination_addr),
      type: type,
      code: code,
      checksum: checksum,
      data: data
    }
  end

  # Echo Reply
  defp parse_payload(0, 0, payload) do
    <<identifier::16, sequence::16, data::bytes>> = payload

    %{
      identifier: identifier,
      sequence: sequence,
      data: data
    }
  end

  defp parse_payload(type, code, payload) do
    %{
      type: type,
      code: code,
      payload: payload
    }
  end

  def checksum(data), do: checksum(data, 0)

  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  # Pad the data if it's not divisable by 16 bits
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)

  defp checksum(<<>>, sum) do
    <<left::16, right::16>> = <<sum::32>>
    <<bnot(left + right)::big-integer-size(16)>>
  end

  defp ip_tuple(ip) when is_integer(ip) do
    <<a::8, b::8, c::8, d::8>> = <<ip::32>>
    {a, b, c, d}
  end
end
