defmodule AppWeb.LoginController do
  use AppWeb, :controller

  def login(conn, %{"token" => token}) do
    Phoenix.Token.verify(AppWeb.Endpoint, "username", token, max_age: 60)
    |> case do
      {:ok, username} ->
        conn
        |> put_session(:username, username)
        |> render( "success.html", username: username)

      {:error, error} ->
        render(conn, "failure.html", error: error)
    end
  end
end
