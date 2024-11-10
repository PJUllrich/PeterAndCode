defmodule App.DatapointsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `App.Datapoints` context.
  """

  @doc """
  Generate a datapoint.
  """
  def datapoint_fixture(attrs \\ %{}) do
    {:ok, datapoint} =
      attrs
      |> Enum.into(%{
        average: 120.5,
        count: 42,
        sum: 120.5
      })
      |> App.Datapoints.create_datapoint()

    datapoint
  end
end
