defmodule StocksWeb.PageController do
  use StocksWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
