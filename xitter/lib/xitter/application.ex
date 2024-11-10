defmodule Xitter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      XitterWeb.Telemetry,
      Xitter.Repo,
      {DNSCluster, query: Application.get_env(:xitter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Xitter.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Xitter.Finch},
      # Start a worker by calling: Xitter.Worker.start_link(arg)
      # {Xitter.Worker, arg},
      # Start to serve requests, typically the last entry
      XitterWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :xitter]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xitter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XitterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
