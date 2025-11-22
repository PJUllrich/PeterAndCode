defmodule App.UserRepo do
  use App, :repository

  alias App.User

  @valid_fields [
    :age
  ]

  def persist(%User{} = user) do
    user
    |> cast(%{}, @valid_fields)
    |> Repo.insert()
  end

  def get(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  def update(user) do
    values = Map.take(user, @valid_fields)

    %User{id: user.id}
    |> cast(values, @valid_fields)
    |> Repo.update()
  end
end
