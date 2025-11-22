defmodule Icmp.Ping do
  @moduledoc """
  Sends a Ping request to a domain and returns the request time and response data.
  """

  import Bitwise

  @doc "Send a Ping request to a given domain."
  def send(domain, ttl \\ 128, timeout \\ 15)

  def send(domain, ttl, timeout) when is_binary(domain) do
    domain
    |> get_ip()
    |> send(ttl, timeout)
  end

  def send(ip, ttl, timeout) when is_tuple(ip) do
    # Echo Request
    type = 8
    code = 0
    id = :rand.uniform(65535)
    sequence = 1
    payload = "ping"

    packet = encode(type, code, id, sequence, payload)

    {:ok, pid} = Icmp.Socket.start_link([])

    response = Icmp.Socket.send(pid, packet, ip, ttl, timeout)

    :ok = Icmp.Socket.stop(pid)

    with {:ok, time, reply_packet} <- response do
      {:ok, decode(reply_packet, time)}
    end
  end

  @doc "Returns the IPv4 as Tuple for a given Domain."
  def get_ip(domain) when is_binary(domain) do
    {:ok, {:hostent, _, _, :inet, 4, [ip | _]}} = :inet.gethostbyname(String.to_charlist(domain))
    ip
  end

  @doc "Returns the domain for a given IP."
  def get_domain(ip) when is_tuple(ip) do
    with {:ok, {:hostent, domain, [], :inet, _version, _ip}} <- :inet_res.gethostbyaddr(ip) do
      {:ok, List.to_string(domain)}
    end
  end

  # Builds an ICMP packet which consists of a header and data section.
  #
  # 0                   1                   2                   3
  # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |      Type     |      Code     |           Checksum          |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |     Rest of Header - Varies based on ICMP type and code     |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                             Data                            |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  #
  defp encode(type, code, id, sequence, payload) do
    header = <<type, code, 0::16, id::16, sequence::16>>

    checksum = checksum(header <> payload)

    <<
      # Line 1
      type::8,
      code::8,
      checksum::binary-size(2),
      # Line 2
      id::16,
      sequence::16,
      # Line 3
      payload::binary
    >>
  end

  # The IPv4 header of the ICMP response packet looks like this:
  #
  # 0                   1                   2                   3
  # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |Version|  IHL  |Type of Service|          Total Length       |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |          Identification       |Flags|     Fragment Offset   |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # | Time to Live  |   Protocol    |    Header Checksum          |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                         Source Address                      |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                      Destination Address                    |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |                      (Optional options)                     |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  # |     Type      |   Code        |         Checksum            |
  # +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  #
  # IHL: Internet Header Length
  #
  # This is an IPv4 Header: https://en.wikipedia.org/wiki/IPv4
  # Taken from: https://book.huihoo.com/iptables-tutorial/x1078.htm
  defp decode(packet, time) do
    <<_ihl_version::4, ihl::4, _rest::bytes>> = packet
    <<header::bytes-size(ihl * 4), payload::bytes>> = packet

    <<
      # Line 1
      ihl_version::4,
      ihl::4,
      tos::8,
      total_length::16,
      # Line 2
      identification::16,
      flags::3,
      offset::13,
      # Line 3
      ttl::8,
      protocol::8,
      header_checksum::16,
      # Line 4
      source_addr::32,
      # Line 5
      destination_addr::32,
      options::bytes
    >> = header

    <<type::8, code::8, checksum::16, data::bytes>> = payload

    info = parse_payload(type, code, data)

    source_addr = ip_tuple(source_addr)

    source_domain =
      case get_domain(source_addr) do
        {:ok, domain} -> domain
        _error -> :inet.ntoa(source_addr)
      end

    destination_addr = ip_tuple(destination_addr)

    %{
      time: time,
      ihl_version: ihl_version,
      ihl: ihl,
      tos: tos,
      total_length: total_length,
      identification: identification,
      flags: flags,
      offset: offset,
      ttl: ttl,
      protocol: protocol,
      options: options,
      header_checksum: <<header_checksum::16>>,
      source_addr: source_addr,
      source_domain: source_domain,
      destination_addr: destination_addr,
      type: type,
      code: code,
      checksum: <<checksum::16>>,
      info: info
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
  # Pad the data if it's not divisible by 16 bits
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
