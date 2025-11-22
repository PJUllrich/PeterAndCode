defmodule Icmp.Traceroute do
  @moduledoc """
  Performs a traceroute request to a given domain.
  """

  require Logger

  alias Icmp.Ping

  def send(domain, max_hops \\ 20) when is_binary(domain) do
    ip = Ping.get_ip(domain)

    do_send(ip, 1, max_hops, [])
  end

  defp do_send(_ip, _ttl, 0 = _max_hops, trace) do
    {:error, :max_hops_exceeded, Enum.reverse(trace)}
  end

  defp do_send(ip, ttl, max_hops, trace) do
    case Ping.send(ip, ttl, 1) do
      {:ok, %{time: time, source_addr: source_addr} = response} when source_addr == ip ->
        log_response(ttl, response)
        trace = [{ttl, time, response} | trace]
        {:ok, trace}

      {:ok, response} ->
        log_response(ttl, response)
        trace = [{ttl, response.time, response} | trace]
        do_send(ip, ttl + 1, max_hops - 1, trace)

      {:error, error} ->
        log_error(ttl, error)
        trace = [{ttl, error} | trace]
        do_send(ip, ttl + 1, max_hops - 1, trace)
    end
  end

  defp log_response(ttl, %{time: time, source_domain: source_domain, source_addr: source_addr}) do
    IO.puts(
      "#{ttl} #{source_domain} (#{:inet.ntoa(source_addr)}) #{Float.round(time / 1000, 3)}ms"
    )
  end

  defp log_error(ttl, error) do
    IO.puts("#{ttl} #{error}")
  end
end
