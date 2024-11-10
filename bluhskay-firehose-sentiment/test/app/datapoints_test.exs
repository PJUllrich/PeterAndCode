defmodule App.DatapointsTest do
  use App.DataCase

  alias App.Datapoints

  describe "datapoints" do
    alias App.Datapoints.Datapoint

    import App.DatapointsFixtures

    @invalid_attrs %{count: nil, sum: nil, average: nil}

    test "list_datapoints/0 returns all datapoints" do
      datapoint = datapoint_fixture()
      assert Datapoints.list_datapoints() == [datapoint]
    end

    test "get_datapoint!/1 returns the datapoint with given id" do
      datapoint = datapoint_fixture()
      assert Datapoints.get_datapoint!(datapoint.id) == datapoint
    end

    test "create_datapoint/1 with valid data creates a datapoint" do
      valid_attrs = %{count: 42, sum: 120.5, average: 120.5}

      assert {:ok, %Datapoint{} = datapoint} = Datapoints.create_datapoint(valid_attrs)
      assert datapoint.count == 42
      assert datapoint.sum == 120.5
      assert datapoint.average == 120.5
    end

    test "create_datapoint/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Datapoints.create_datapoint(@invalid_attrs)
    end

    test "update_datapoint/2 with valid data updates the datapoint" do
      datapoint = datapoint_fixture()
      update_attrs = %{count: 43, sum: 456.7, average: 456.7}

      assert {:ok, %Datapoint{} = datapoint} = Datapoints.update_datapoint(datapoint, update_attrs)
      assert datapoint.count == 43
      assert datapoint.sum == 456.7
      assert datapoint.average == 456.7
    end

    test "update_datapoint/2 with invalid data returns error changeset" do
      datapoint = datapoint_fixture()
      assert {:error, %Ecto.Changeset{}} = Datapoints.update_datapoint(datapoint, @invalid_attrs)
      assert datapoint == Datapoints.get_datapoint!(datapoint.id)
    end

    test "delete_datapoint/1 deletes the datapoint" do
      datapoint = datapoint_fixture()
      assert {:ok, %Datapoint{}} = Datapoints.delete_datapoint(datapoint)
      assert_raise Ecto.NoResultsError, fn -> Datapoints.get_datapoint!(datapoint.id) end
    end

    test "change_datapoint/1 returns a datapoint changeset" do
      datapoint = datapoint_fixture()
      assert %Ecto.Changeset{} = Datapoints.change_datapoint(datapoint)
    end
  end
end
