defmodule Habit.Repo do
  use Ecto.Repo,
    otp_app: :habit,
    adapter: Ecto.Adapters.Postgres
end
