defmodule App.PKIStorage do
  @moduledoc false

  import Ecto.Query

  alias App.Repo
  alias App.U2FKey

  alias U2FEx.PKIStorageBehaviour

  @behaviour U2FEx.PKIStorageBehaviour

  @impl PKIStorageBehaviour
  def list_key_handles_for_user(username) do
    keys =
      from(u in U2FKey,
        where: u.username == ^username,
        select: map(u, [:version, :key_handle, :app_id])
      )
      |> Repo.all()

    {:ok, keys}
  end

  @impl PKIStorageBehaviour
  def get_public_key_for_user(username, key_handle) do
    from(u in U2FKey,
      where: u.username == ^username and u.key_handle == ^key_handle
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :public_key_not_found}
      %U2FKey{public_key: public_key} -> {:ok, public_key}
    end
  end

  def create_u2f_key(username, %U2FEx.KeyMetadata{} = key_metadata) do
    attrs = Map.merge(Map.from_struct(key_metadata), %{username: username})

    %U2FKey{}
    |> U2FKey.changeset(attrs)
    |> Repo.insert()
  end
end
