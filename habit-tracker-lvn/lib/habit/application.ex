defmodule Habit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HabitWeb.Telemetry,
      Habit.Repo,
      {DNSCluster, query: Application.get_env(:habit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Habit.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Habit.Finch},
      # Start a worker by calling: Habit.Worker.start_link(arg)
      # {Habit.Worker, arg},
      # Start to serve requests, typically the last entry
      HabitWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Habit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HabitWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
