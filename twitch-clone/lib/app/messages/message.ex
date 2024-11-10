defmodule App.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :username, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:username, :content])
    |> validate_required([:username, :content])
    |> validate_required([:username, :content])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_length(:content, min: 1, max: 250)
  end
end
