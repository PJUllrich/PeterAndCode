defmodule LocationTrackerServer.Locations do
  @moduledoc """
  The Locations context.
  """

  import Ecto.Query, warn: false
  alias LocationTrackerServer.Repo

  alias LocationTrackerServer.Locations.Point

  @doc """
  Returns the list of location_points.

  ## Examples

      iex> list_location_points()
      [%Point{}, ...]

  """
  def list_location_points do
    Repo.all(Point)
  end

  @doc """
  Gets a single point.

  Raises `Ecto.NoResultsError` if the Point does not exist.

  ## Examples

      iex> get_point!(123)
      %Point{}

      iex> get_point!(456)
      ** (Ecto.NoResultsError)

  """
  def get_point!(id), do: Repo.get!(Point, id)

  @doc """
  Creates a point.

  ## Examples

      iex> create_point(%{field: value})
      {:ok, %Point{}}

      iex> create_point(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_point(attrs \\ %{}) do
    %Point{}
    |> Point.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, point} = result ->
        Phoenix.PubSub.broadcast(
          LocationTrackerServer.PubSub,
          "location_points",
          {:add_point, point}
        )

        result

      error ->
        error
    end
  end

  @doc """
  Updates a point.

  ## Examples

      iex> update_point(point, %{field: new_value})
      {:ok, %Point{}}

      iex> update_point(point, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_point(%Point{} = point, attrs) do
    point
    |> Point.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a point.

  ## Examples

      iex> delete_point(point)
      {:ok, %Point{}}

      iex> delete_point(point)
      {:error, %Ecto.Changeset{}}

  """
  def delete_point(%Point{} = point) do
    Repo.delete(point)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking point changes.

  ## Examples

      iex> change_point(point)
      %Ecto.Changeset{data: %Point{}}

  """
  def change_point(%Point{} = point, attrs \\ %{}) do
    Point.changeset(point, attrs)
  end
end
