defmodule GameOfLifeWeb.Router do
  use GameOfLifeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GameOfLifeWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GameOfLifeWeb do
    pipe_through :browser

    live "/", PageLive, :index

    live_dashboard "/dashboard", metrics: GameOfLifeWeb.Telemetry
  end

  # Other scopes may use custom stacks.
  # scope "/api", GameOfLifeWeb do
  #   pipe_through :api
  # end
end
