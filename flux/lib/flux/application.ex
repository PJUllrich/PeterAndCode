defmodule Flux.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FluxWeb.Telemetry,
      Flux.Repo,
      {DNSCluster, query: Application.get_env(:flux, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Flux.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Flux.Finch},
      # Start a worker by calling: Flux.Worker.start_link(arg)
      # {Flux.Worker, arg},
      # Start to serve requests, typically the last entry
      FluxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Flux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FluxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
