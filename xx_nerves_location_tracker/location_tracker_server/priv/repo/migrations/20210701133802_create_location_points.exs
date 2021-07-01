defmodule LocationTrackerServer.Repo.Migrations.CreateLocationPoints do
  use Ecto.Migration

  def change do
    create table(:location_points) do
      add :longitude, :float
      add :latitude, :float

      timestamps()
    end

  end
end
