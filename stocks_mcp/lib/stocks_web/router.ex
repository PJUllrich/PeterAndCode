defmodule StocksWeb.Router do
  use StocksWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StocksWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", StocksWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/mcp" do
    forward "/", EMCP.Transport.StreamableHTTP, server: Stocks.MCPServer
  end
end
