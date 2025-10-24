defmodule Wal.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :title, :string
      add :from, :utc_datetime
      add :until, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
