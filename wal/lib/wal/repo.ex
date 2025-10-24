defmodule Wal.Repo do
  use Ecto.Repo,
    otp_app: :wal,
    adapter: Ecto.Adapters.Postgres
end
