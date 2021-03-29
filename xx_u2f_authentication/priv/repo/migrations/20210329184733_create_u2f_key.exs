defmodule App.Repo.Migrations.CreateU2fKey do
  use Ecto.Migration

  def change do
    create table(:u2f_keys) do
      add(:public_key, :string, size: 128)
      add(:key_handle, :string, size: 128)
      add(:version, :string, size: 10, default: "U2F_V2")
      add(:app_id, :string)
      add(:username, :string)

      timestamps()
    end
  end
end
