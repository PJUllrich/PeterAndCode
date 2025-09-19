defmodule Tracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TrackerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tracker.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Tracker.Finch},
      # Start the ReadSB manager for ADS-B data processing
      Tracker.ReadsbManager,
      # Start the TCP socket that connects to readsb to receive JSON payloads
      Tracker.ADSBReceiver,
      TrackerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
