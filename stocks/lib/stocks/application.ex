defmodule Stocks.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    EMCP.SessionStore.ETS.init()

    children = [
      StocksWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:stocks, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Stocks.PubSub},
      Stocks.Finnhub,
      StocksWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Stocks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StocksWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
