defmodule App.Datapoints do
  @moduledoc """
  The Datapoints context.
  """

  import Ecto.Query, warn: false
  alias App.Repo

  alias App.Datapoints.Datapoint

  @doc """
  Returns the list of datapoints.

  ## Examples

      iex> list_datapoints()
      [%Datapoint{}, ...]

  """
  def list_datapoints do
    Repo.all(Datapoint)
  end

  def get_average_per_minute() do
    result =
      Ecto.Adapters.SQL.query!(Repo, """
        SELECT
            time_bucket('1 minute'::interval, inserted_at) as bucket,
            avg(average)
        FROM datapoints
        GROUP BY bucket
        ORDER BY bucket ASC;
      """)

    Enum.map(result.rows, fn [dt, avg] -> %{inserted_at: dt, average: avg} end)
  end

  @doc """
  Gets a single datapoint.

  Raises `Ecto.NoResultsError` if the Datapoint does not exist.

  ## Examples

      iex> get_datapoint!(123)
      %Datapoint{}

      iex> get_datapoint!(456)
      ** (Ecto.NoResultsError)

  """
  def get_datapoint!(id), do: Repo.get!(Datapoint, id)

  @doc """
  Creates a datapoint.

  ## Examples

      iex> create_datapoint(%{field: value})
      {:ok, %Datapoint{}}

      iex> create_datapoint(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_datapoint(attrs \\ %{}) do
    %Datapoint{}
    |> Datapoint.changeset(attrs)
    |> Repo.insert()
    |> broadcast()
  end

  defp broadcast({:ok, datapoint}) do
    Phoenix.PubSub.broadcast!(App.PubSub, "new-datapoint", {:datapoint, datapoint})
    {:ok, datapoint}
  end

  defp broadcast(error), do: error

  @doc """
  Updates a datapoint.

  ## Examples

      iex> update_datapoint(datapoint, %{field: new_value})
      {:ok, %Datapoint{}}

      iex> update_datapoint(datapoint, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_datapoint(%Datapoint{} = datapoint, attrs) do
    datapoint
    |> Datapoint.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a datapoint.

  ## Examples

      iex> delete_datapoint(datapoint)
      {:ok, %Datapoint{}}

      iex> delete_datapoint(datapoint)
      {:error, %Ecto.Changeset{}}

  """
  def delete_datapoint(%Datapoint{} = datapoint) do
    Repo.delete(datapoint)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking datapoint changes.

  ## Examples

      iex> change_datapoint(datapoint)
      %Ecto.Changeset{data: %Datapoint{}}

  """
  def change_datapoint(%Datapoint{} = datapoint, attrs \\ %{}) do
    Datapoint.changeset(datapoint, attrs)
  end
end
