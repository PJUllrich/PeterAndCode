defmodule LocationTrackerServer.Locations.Point do
  use Ecto.Schema
  import Ecto.Changeset

  schema "location_points" do
    field :latitude, :float
    field :longitude, :float

    timestamps()
  end

  @doc false
  def changeset(point, attrs) do
    point
    |> cast(attrs, [:longitude, :latitude])
    |> validate_required([:longitude, :latitude])
  end
end
