defmodule App.Datapoints.Datapoint do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:average, :sum, :count, :inserted_at]}
  @primary_key false
  schema "datapoints" do
    field :average, :float
    field :sum, :float
    field :count, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(datapoint, attrs) do
    datapoint
    |> cast(attrs, [:average, :sum, :count])
    |> validate_required([:average, :sum, :count])
  end
end
