defmodule Wal.MeetingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Wal.Meetings` context.
  """

  @doc """
  Generate a meeting.
  """
  def meeting_fixture(attrs \\ %{}) do
    {:ok, meeting} =
      attrs
      |> Enum.into(%{
        from: ~U[2025-10-23 11:06:00Z],
        title: "some title",
        until: ~U[2025-10-23 11:06:00Z]
      })
      |> Wal.Meetings.create_meeting()

    meeting
  end
end
