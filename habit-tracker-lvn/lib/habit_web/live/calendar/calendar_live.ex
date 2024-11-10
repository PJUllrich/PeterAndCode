defmodule HabitWeb.CalendarLive do
  use HabitWeb, :live_view
  use HabitNative, :live_view

  def render(assigns) do
    ~H"""
    <h1>Hello from the Web!</h1>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tab, "calendar")}
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