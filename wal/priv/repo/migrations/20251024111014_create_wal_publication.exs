defmodule Wal.Repo.Migrations.CreateWalPublication do
  use Ecto.Migration

  def change do
    execute """
            CREATE EXTENSION IF NOT EXISTS pg_walinspect;
            """,
            """
            DROP EXTENSION IF EXISTS pg_walinspect;
            """

    execute """
            CREATE PUBLICATION postgrex_publication FOR ALL TABLES;
            """,
            """
            DROP PUBLICATION IF EXISTS postgrex_publication;
            """
  end
end
