defmodule Traceroute do
  @moduledoc """
  Performs a traceroute request to a given domain.
  """

  require Logger

  alias Traceroute.Ping
  alias Traceroute.Utils

  def run(domain, opts \\ []) when is_binary(domain) do
    default_opts = [
      protocol: :icmp,
      max_hops: 20,
      max_retries: 3,
      timeout: 1
    ]

    opts = default_opts |> Keyword.merge(opts) |> Map.new()

    ip = Utils.get_ip(domain)

    do_run(ip, 1, opts.max_hops, opts.max_retries, [], opts)
  end

  defp do_run(_ip, _ttl, 0 = _max_hops, _retries, trace, _opts) do
    {:error, :max_hops_exceeded, Enum.reverse(trace)}
  end

  defp do_run(ip, ttl, max_hops, retries, trace, opts) do
    case Ping.run(ip, ttl: ttl, timeout: opts.timeout, protocol: opts.protocol) do
      {:ok, %{time: time, header: %{source_addr: source_addr}} = response}
      when source_addr == ip ->
        log_response(ttl, response)
        trace = [{ttl, time, response} | trace]
        {:ok, trace}

      {:ok, response} ->
        log_response(ttl, response)
        trace = [{ttl, response.time, response} | trace]
        do_run(ip, ttl + 1, max_hops - 1, 0, trace, opts)

      {:error, :timeout} ->
        stars = "*" |> List.duplicate(min(retries + 1, opts.max_retries)) |> Enum.join(" ")

        if retries < opts.max_retries do
          log_timeout(ttl, stars)
          do_run(ip, ttl, max_hops, retries + 1, trace, opts)
        else
          log_timeout(ttl, stars <> "\n")
          do_run(ip, ttl + 1, max_hops - 1, 0, [{ttl, :timeout} | trace], opts)
        end

      {:error, error} ->
        log_error(ttl, error)
        trace = [{ttl, error} | trace]
        do_run(ip, ttl + 1, max_hops - 1, 0, trace, opts)
    end
  end

  defp log_response(ttl, %{
         time: time,
         header: %{source_domain: source_domain, source_addr: source_addr}
       }) do
    request_time = Float.round(time / 1000, 3)
    IO.write("\r#{ttl} #{source_domain} (#{:inet.ntoa(source_addr)}) #{request_time}ms\n")
  end

  defp log_timeout(ttl, error) do
    IO.write("\r#{ttl} #{error}")
  end

  defp log_error(ttl, error) do
    IO.write("\r#{ttl} #{error}\n")
  end
end
