defmodule App.Repo.Migrations.AddEmailHashToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_hash, :binary
    end
  end
end
