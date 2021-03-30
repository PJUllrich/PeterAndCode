defmodule AppWeb.PageLive do
  use AppWeb, :live_view

  require Logger

  alias App.{PKIStorage, U2FKey}
  alias U2FEx.KeyMetadata

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("start_registration", %{"registration" => %{"username" => username}}, socket) do
    {:ok, %{registerRequests: register_requests}} = U2FEx.start_registration(username)

    socket =
      socket
      |> assign(:username, username)
      |> push_event("register", %{registerRequests: register_requests})

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "finish_registration",
        %{"response" => device_response},
        %{assigns: %{username: username}} = socket
      ) do
    {:ok, %KeyMetadata{} = key_metadata} = U2FEx.finish_registration(username, device_response)
    {:ok, %U2FKey{} = key} = PKIStorage.create_u2f_key(username, key_metadata)

    {:noreply, assign(socket, :u2f_key, key)}
  end

  @impl true
  def handle_event("start_login", %{"login" => %{"username" => username}}, socket) do
    {:ok, %{challenge: challenge, registeredKeys: registered_keys}} =
      U2FEx.start_authentication(username)

    sign_requests = Enum.map(registered_keys, &Map.merge(&1, %{challenge: challenge}))

    socket =
      socket
      |> assign(:username, username)
      |> push_event("login", %{signRequests: sign_requests})

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "finish_login",
        %{"response" => device_response},
        %{assigns: %{username: username}} = socket
      ) do
    U2FEx.finish_authentication(username, device_response |> Jason.encode!())
    |> case do
      :ok ->
        {:noreply, assign(socket, :current_username, username)}

      error ->
        Logger.error(inspect(error))
        {:noreply, put_flash(socket, :error, "Login failed.")}
    end
  end
end
