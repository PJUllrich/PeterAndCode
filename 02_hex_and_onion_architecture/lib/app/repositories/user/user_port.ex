defmodule App.UserPort do
  @callback persist(App.User) :: {:ok, App.User} | {:error, Ecto.Changeset}
end
