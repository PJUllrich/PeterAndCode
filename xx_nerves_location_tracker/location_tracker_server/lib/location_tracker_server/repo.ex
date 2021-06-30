defmodule LocationTrackerServer.Repo do
  use Ecto.Repo,
    otp_app: :location_tracker_server,
    adapter: Ecto.Adapters.Postgres
end
