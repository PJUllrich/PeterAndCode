defmodule Wal.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :title, :string
    field :from, :utc_datetime
    field :until, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:title, :from, :until])
    |> validate_required([:title, :from, :until])
  end
end
