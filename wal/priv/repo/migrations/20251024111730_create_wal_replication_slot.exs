defmodule Wal.Repo.Migrations.CreateWalReplicationSlot do
  use Ecto.Migration

  def change do
    execute """
            SELECT pg_create_logical_replication_slot('postgrex', 'pgoutput', false);
            """,
            """
            SELECT pg_drop_replication_slot('postgrex');
            """
  end
end
