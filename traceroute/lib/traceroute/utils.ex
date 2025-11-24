defmodule Traceroute.Utils do
  @moduledoc """
  Implements various helper functions.
  """

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

  @doc "Converts an integer to an IPv4 tuple"
  def ipv4_tuple(ip) when is_integer(ip) do
    <<a::8, b::8, c::8, d::8>> = <<ip::32>>
    {a, b, c, d}
  end
end
