defmodule AppWeb.IndexLive do
  use AppWeb, :live_view

  @presence "stream:audience"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full min-h-screen flex flex-col lg:flex-row justify-between items-scretch px-4 lg:px-0">
      <div class="w-60 hidden lg:block"></div>
      <div class="grow flex justify-center items-center">
        <div :if={!@live}>
          Peter's currently not live!
        </div>
        <div
          :if={@live}
          id="target"
          phx-update="ignore"
          phx-hook="Player"
          data-source="/stream/index.m3u8"
          autoplay
          playsinline
        >
        </div>
      </div>
      <div class="max-h-[70vh] lg:max-h-screen flex flex-col w-full lg:w-60">
        <div>User Count: <%= @user_count %></div>
        <.form :let={form} for={@form} phx-submit="send" class="flex flex-col">
          <.input
            field={form[:username]}
            type="text"
            placeholder="username"
            data-1p-ignore
            data-lpignore
          />
          <.input field={form[:content]} type="text" placeholder="message" />
          <.button class="mt-2">Post</.button>
        </.form>
        <div
          id="messages"
          phx-update="stream"
          class="grow w-full overflow-y-auto mt-4 break-all bg-gray-900 rounded flex flex-col space-y-1 text-gray-300 p-2"
        >
          <span :for={{dom_id, message} <- @streams.messages} id={dom_id} class="w-full">
            <span class="font-bold text-xs"><%= message.username %>:</span>
            <span class="text-sm"><%= message.content %></span>
          </span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :uuid, Ecto.UUID.generate())

    if connected?(socket) do
      Phoenix.PubSub.subscribe(App.PubSub, "stream-state")
      join_presence(socket.assigns.uuid)
    end

    messages = if connected?(socket), do: App.Messages.list_messages(), else: []
    stream_state = App.StreamState.get_state()
    changeset = App.Messages.change_message(%App.Messages.Message{})

    {:ok,
     socket
     |> assign_form(changeset)
     |> assign(live: stream_state.live, user_count: 1)
     |> stream(:messages, messages)
     |> handle_joins(AppWeb.Presence.list(@presence))}
  end

  @impl true
  def handle_info({:changed, stream_state}, socket) do
    {:noreply, assign(socket, :live, stream_state.live)}
  end

  @impl true
  def handle_info({:message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  @impl true
  def handle_event(
        "send",
        %{"message" => message},
        socket
      ) do
    case App.Messages.create_message(message) do
      {:ok, _data} ->
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp join_presence(uuid) do
    {:ok, _} =
      AppWeb.Presence.track(self(), @presence, uuid, %{
        joined_at: :os.system_time(:seconds)
      })

    Phoenix.PubSub.subscribe(App.PubSub, @presence)
  end

  defp handle_joins(socket, joins) do
    joins = joins |> Enum.filter(fn {id, _value} -> id != socket.assigns.uuid end) |> Map.new()
    user_count = socket.assigns[:user_count] || 0
    assign(socket, :user_count, user_count + map_size(joins))
  end

  defp handle_leaves(socket, leaves) do
    user_count = socket.assigns[:user_count] || 0
    assign(socket, :user_count, user_count - map_size(leaves))
  end
end
