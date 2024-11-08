defmodule WebChain.Repo do
  use Ecto.Repo,
    otp_app: :web_chain,
    adapter: Ecto.Adapters.Postgres
end
