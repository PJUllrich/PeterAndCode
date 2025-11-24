defmodule Traceroute.Ping do
  @moduledoc """
  Sends a Ping request to a domain and returns the request time and response data.
  """

  alias Traceroute.Protocols
  alias Traceroute.Sockets
  alias Traceroute.Utils

  @doc "Send a Ping request to a given domain."

  def run(domain, opts \\ [])

  def run(domain, opts) when is_binary(domain) do
    domain
    |> Utils.get_ip()
    |> run(opts)
  end

  def run(ip, opts) when is_tuple(ip) do
    default_opts = [
      protocol: :icmp,
      ttl: 128,
      timeout: 15
    ]

    opts = default_opts |> Keyword.merge(opts) |> Map.new()
    do_send(opts.protocol, ip, opts)
  end

  defp do_send(:icmp, ip, opts) do
    # Echo Request
    type = 8
    code = 0
    id = :rand.uniform(65535)
    sequence = 1
    payload = "ping"

    type
    |> Protocols.Icmp.encode_datagram(code, id, sequence, payload)
    |> Sockets.Icmp.one_off_send(ip, opts.ttl, opts.timeout)
    |> parse_response()
  end

  defp do_send(:udp, ip, opts) do
    "probe"
    |> Sockets.Udp.one_off_send(ip, opts.ttl, opts.timeout)
    |> parse_response()
  end

  defp parse_response({:ok, time, reply_packet}) do
    {header, payload} = Protocols.Ipv4.split_header(reply_packet)
    data = Protocols.Icmp.decode_datagaram(payload)

    reply = %{header: header, data: data, time: time}

    {:ok, reply}
  end

  defp parse_response(error), do: error
end
