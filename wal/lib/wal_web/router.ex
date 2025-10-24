defmodule WalWeb.Router do
  use WalWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", WalWeb do
    pipe_through :api
  end
end
