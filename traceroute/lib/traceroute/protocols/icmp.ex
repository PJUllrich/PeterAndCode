defmodule Traceroute.Protocols.Icmp do
  @moduledoc """
  Implements the encoding and decoding of ICMP packets.

  See: https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol
  """

  import Bitwise

  @doc """
  Encodes an ICMP datagram which consists of a header and data section.

  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |      Type     |      Code     |           Checksum          |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     Rest of Header - Varies based on ICMP type and code     |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                             Data                            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

  """
  def encode_datagram(type, code, id, sequence, payload) do
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

  def decode_datagaram(payload) do
    <<type::8, code::8, checksum::16, _unused::8, _length::8, _next_hop_mtu::16, data::bytes>> =
      payload

    reply = parse_reply(type, code, data)

    %{
      type: type,
      code: code,
      checksum: <<checksum::16>>,
      reply: reply
    }
  end

  # Echo Reply
  defp parse_reply(0, 0, payload) do
    <<identifier::16, sequence::16, data::bytes>> = payload

    %{
      type: :echo_reply,
      identifier: identifier,
      sequence: sequence,
      data: data
    }
  end

  # Time exceeded
  defp parse_reply(11, _reply_code, payload) do
    <<_ihl_version::4, ihl::4, rest::bytes>> = payload
    <<ipv4_header::bytes-size(ihl * 4 - 1), data::bytes>> = rest
    <<_::bytes-size(8), protocol::8, _rest::bytes>> = ipv4_header

    # Parse the first bytes of the original datagram which gives the id for correlation.
    <<
      # Line 1
      type::8,
      code::8,
      checksum::binary-size(2),
      # Line 2
      id::16,
      sequence::16,
      rest::bytes
    >> = data

    %{
      type: :time_exceeded,
      protocol: protocol,
      request_datagram: %{
        type: type,
        code: code,
        checksum: checksum,
        id: id,
        sequence: sequence,
        rest: rest
      }
    }
  end

  # Destination Unreachable
  #
  # Returned from destination when UDP package reaches it but can't connect to the destination port
  # which is intended. This basically means that the packet has reached the destination server.
  defp parse_reply(3, 3, payload) do
    <<_ihl_version::4, ihl::4, rest::bytes>> = payload
    <<ipv4_header::bytes-size(ihl * 4 - 1), data::bytes>> = rest
    <<_::bytes-size(8), protocol::8, _rest::bytes>> = ipv4_header

    # Map the protocol
    # https://en.wikipedia.org/wiki/IPv4#Protocol
    protocol =
      case protocol do
        1 -> :icmp
        6 -> :tcp
        17 -> :udp
      end

    data =
      if protocol == :udp do
        Traceroute.Protocols.Udp.parse_datagram(data)
      else
        data
      end

    %{
      type: :destination_unreachable,
      protocol: protocol,
      data: data
    }
  end

  defp parse_reply(_type, _code, payload) do
    %{
      type: :unparsed,
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
end
