defmodule App.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :binary

      timestamps()
    end

  end
end
