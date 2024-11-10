defmodule App.Repo.Migrations.CreateDatapoints do
  use Ecto.Migration

  import Timescale.Migration

  def up do
    create_timescaledb_extension()

    create_if_not_exists table(:datapoints, primary_key: false) do
      add :average, :float
      add :sum, :float
      add :count, :integer

      timestamps(type: :utc_datetime)
    end

    create_hypertable(:datapoints, :inserted_at)
  end

  def down do
    drop(table(:datapoints), mode: :cascade)
    drop_timescaledb_extension()
  end
end
