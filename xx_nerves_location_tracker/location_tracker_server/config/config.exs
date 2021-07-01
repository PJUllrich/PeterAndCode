# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :location_tracker_server,
  ecto_repos: [LocationTrackerServer.Repo],
  channel_token: System.get_env("CHANNEL_TOKEN")

# Configures the endpoint
config :location_tracker_server, LocationTrackerServerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Xg6ddFkudxTPsqg5Jcw+Z3jzKp55QfIFfs+XwsUKynUn51nS+6CFferKMn79bI1b",
  render_errors: [view: LocationTrackerServerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: LocationTrackerServer.PubSub,
  live_view: [signing_salt: "4akbspGu"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
