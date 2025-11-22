defmodule AppWeb.ApiController do
  use AppWeb, :controller

  alias App.UpdateUserAgeService

  def set_user(conn, %{"user_id" => user_id, "new_age" => new_age}) do
    new_age = String.to_integer(new_age)

    UpdateUserAgeService.update_age(user_id: user_id, new_age: new_age)
    |> case do
      :ok -> render(conn, "success.html")
      _error -> render(conn, "error.html")
    end
  end
end
