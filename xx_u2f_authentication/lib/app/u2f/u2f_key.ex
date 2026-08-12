defmodule App.U2FKey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "u2f_keys" do
    field(:public_key, :string)
    field(:key_handle, :string)
    field(:version, :string, size: 10, default: "U2F_V2")
    field(:app_id, :string)
    field(:username, :string)

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:public_key, :key_handle, :version, :app_id, :username])
    |> validate_required([:public_key, :key_handle, :version, :app_id, :username])
  end
end
