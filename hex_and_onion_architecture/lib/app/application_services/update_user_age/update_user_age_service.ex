defmodule App.UpdateUserAgeService do
  use App, :application_service

  alias App.{User, UserRepo}

  def update_age(user_id: user_id, new_age: new_age) do
    with {:ok, user} <- UserRepo.get(user_id),
         {:ok, updated_user} <- User.update_age(user, new_age),
         {:ok, _updated_user} <- UserRepo.update(updated_user) do
      :ok
    end
  end
end
