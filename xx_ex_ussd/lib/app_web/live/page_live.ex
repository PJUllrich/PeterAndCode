defmodule AppWeb.PageLive do
  use AppWeb, :live_view

  @callback_url "http://localhost:4000/api/callback"

  @impl true
  def render(assigns), do: AppWeb.PageView.render("show.html", assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, new_session(socket)}
  end

  @impl true
  def handle_event("button_clicked", %{"value" => value}, socket) do
    {:noreply, update(socket, :ussd_code, &(&1 <> value))}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply, reset_ussd_code(socket)}
  end

  @impl true
  def handle_event("end_session", _params, socket) do
    {:noreply, new_session(socket)}
  end

  @impl true
  def handle_event("call", _params, socket) do
    {:noreply, execute(socket)}
  end

  defp new_session(socket) do
    random_session_id = Enum.random(123_123_123..999_999_999)

    socket
    |> assign(session_id: random_session_id)
    |> show_home_prompt()
  end

  defp execute(socket) do
    result = execute_ussd_code(socket)
    set_prompt(socket, result)
  end

  defp show_home_prompt(socket) do
    socket
    |> reset_ussd_code()
    |> execute()
  end

  defp execute_ussd_code(%{assigns: %{ussd_code: ussd_code, session_id: session_id}}) do
    body =
      %{
        text: ussd_code,
        sessionId: session_id,
        serviceCode: "*123#"
      }
      |> Jason.encode!()

    {:ok, %{body: prompt}} =
      HTTPoison.post(@callback_url, body, [{"Content-Type", "application/json"}])

    prompt
  end

  defp reset_ussd_code(socket) do
    assign(socket, ussd_code: "")
  end

  defp set_prompt(socket, prompt) do
    socket
    |> assign(prompt: prompt)
    |> reset_ussd_code()
  end
end
