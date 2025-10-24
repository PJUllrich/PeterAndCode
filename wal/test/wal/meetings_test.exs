defmodule Wal.MeetingsTest do
  use Wal.DataCase

  alias Wal.Meetings

  describe "meetings" do
    alias Wal.Meetings.Meeting

    import Wal.MeetingsFixtures

    @invalid_attrs %{title: nil, until: nil, from: nil}

    test "list_meetings/0 returns all meetings" do
      meeting = meeting_fixture()
      assert Meetings.list_meetings() == [meeting]
    end

    test "get_meeting!/1 returns the meeting with given id" do
      meeting = meeting_fixture()
      assert Meetings.get_meeting!(meeting.id) == meeting
    end

    test "create_meeting/1 with valid data creates a meeting" do
      valid_attrs = %{title: "some title", until: ~U[2025-10-23 11:06:00Z], from: ~U[2025-10-23 11:06:00Z]}

      assert {:ok, %Meeting{} = meeting} = Meetings.create_meeting(valid_attrs)
      assert meeting.title == "some title"
      assert meeting.until == ~U[2025-10-23 11:06:00Z]
      assert meeting.from == ~U[2025-10-23 11:06:00Z]
    end

    test "create_meeting/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meetings.create_meeting(@invalid_attrs)
    end

    test "update_meeting/2 with valid data updates the meeting" do
      meeting = meeting_fixture()
      update_attrs = %{title: "some updated title", until: ~U[2025-10-24 11:06:00Z], from: ~U[2025-10-24 11:06:00Z]}

      assert {:ok, %Meeting{} = meeting} = Meetings.update_meeting(meeting, update_attrs)
      assert meeting.title == "some updated title"
      assert meeting.until == ~U[2025-10-24 11:06:00Z]
      assert meeting.from == ~U[2025-10-24 11:06:00Z]
    end

    test "update_meeting/2 with invalid data returns error changeset" do
      meeting = meeting_fixture()
      assert {:error, %Ecto.Changeset{}} = Meetings.update_meeting(meeting, @invalid_attrs)
      assert meeting == Meetings.get_meeting!(meeting.id)
    end

    test "delete_meeting/1 deletes the meeting" do
      meeting = meeting_fixture()
      assert {:ok, %Meeting{}} = Meetings.delete_meeting(meeting)
      assert_raise Ecto.NoResultsError, fn -> Meetings.get_meeting!(meeting.id) end
    end

    test "change_meeting/1 returns a meeting changeset" do
      meeting = meeting_fixture()
      assert %Ecto.Changeset{} = Meetings.change_meeting(meeting)
    end
  end
end
