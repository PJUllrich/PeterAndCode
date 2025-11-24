defmodule Traceroute.Protocols.Ipv4 do
  @moduledoc """
  Implements decoding IPv4 Headers.
  """

  alias Traceroute.Utils

  @doc """
  Splits a packet into IPv4 Header and Payload.

  The IPv4 header of the ICMP response packet looks like this:

  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |Version|  IHL  |Type of Service|          Total Length       |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |          Identification       |Flags|     Fragment Offset   |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  | Time to Live  |   Protocol    |    Header Checksum          |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                         Source Address                      |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                      Destination Address                    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                      (Optional options)                     |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     Type      |   Code        |         Checksum            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

  IHL: Internet Header Length

  See: https://en.wikipedia.org/wiki/IPv4#Header
  """
  def split_header(packet) do
    <<_ihl_version::4, ihl::4, _rest::bytes>> = packet
    <<ipv4_header::bytes-size(ihl * 4), payload::bytes>> = packet

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
    >> = ipv4_header

    source_addr = Utils.ipv4_tuple(source_addr)

    source_domain =
      case Traceroute.Utils.get_domain(source_addr) do
        {:ok, domain} -> domain
        _error -> :inet.ntoa(source_addr)
      end

    destination_addr = Utils.ipv4_tuple(destination_addr)

    header = %{
      type: :ipv4,
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
      source_domain: source_domain,
      source_addr: source_addr,
      destination_addr: destination_addr,
      options: options
    }

    {header, payload}
  end
end
