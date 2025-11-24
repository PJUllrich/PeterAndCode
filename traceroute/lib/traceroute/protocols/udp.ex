defmodule Traceroute.Protocols.Udp do
  @moduledoc """
  Parses UDP datagram and headers.
  """

  @doc """
  Parses a UDP datagram.

  See: https://en.wikipedia.org/wiki/User_Datagram_Protocol#UDP_datagram_structure
  """
  def parse_datagram(data) do
    <<source_port::16, dest_port::16, length::16, checksum::16, data::bytes>> = data

    %{
      type: :udp,
      source_port: source_port,
      dest_port: dest_port,
      length: length,
      checksum: checksum,
      data: data
    }
  end
end
