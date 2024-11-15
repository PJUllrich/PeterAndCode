defmodule Flux.Repo do
  use Ecto.Repo,
    otp_app: :flux,
    adapter: Ecto.Adapters.Postgres
end
