defmodule HabitWeb.HabitsLive do
  use HabitWeb, :live_view
  use HabitNative, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tab, "habits")}
  end

  def handle_event("tab-changed", %{ "selection" => tab }, socket) do
    # add query param when tab changes
    route = case tab do
      "calendar" -> ~p"/"
      "habits" -> ~p"/habits"
    end
    {:noreply, push_navigate(socket, to: route, replace: true)}
  end
end