defmodule App.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table("users") do
      add :age, :integer
    end
  end
end
