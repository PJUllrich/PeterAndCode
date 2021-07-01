defmodule LocationTrackerServer.LocationsTest do
  use LocationTrackerServer.DataCase

  alias LocationTrackerServer.Locations

  describe "location_points" do
    alias LocationTrackerServer.Locations.Point

    @valid_attrs %{latitude: 120.5, longitude: 120.5}
    @update_attrs %{latitude: 456.7, longitude: 456.7}
    @invalid_attrs %{latitude: nil, longitude: nil}

    def point_fixture(attrs \\ %{}) do
      {:ok, point} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Locations.create_point()

      point
    end

    test "list_location_points/0 returns all location_points" do
      point = point_fixture()
      assert Locations.list_location_points() == [point]
    end

    test "get_point!/1 returns the point with given id" do
      point = point_fixture()
      assert Locations.get_point!(point.id) == point
    end

    test "create_point/1 with valid data creates a point" do
      assert {:ok, %Point{} = point} = Locations.create_point(@valid_attrs)
      assert point.latitude == 120.5
      assert point.longitude == 120.5
    end

    test "create_point/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Locations.create_point(@invalid_attrs)
    end

    test "update_point/2 with valid data updates the point" do
      point = point_fixture()
      assert {:ok, %Point{} = point} = Locations.update_point(point, @update_attrs)
      assert point.latitude == 456.7
      assert point.longitude == 456.7
    end

    test "update_point/2 with invalid data returns error changeset" do
      point = point_fixture()
      assert {:error, %Ecto.Changeset{}} = Locations.update_point(point, @invalid_attrs)
      assert point == Locations.get_point!(point.id)
    end

    test "delete_point/1 deletes the point" do
      point = point_fixture()
      assert {:ok, %Point{}} = Locations.delete_point(point)
      assert_raise Ecto.NoResultsError, fn -> Locations.get_point!(point.id) end
    end

    test "change_point/1 returns a point changeset" do
      point = point_fixture()
      assert %Ecto.Changeset{} = Locations.change_point(point)
    end
  end
end
