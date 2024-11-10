defmodule XitterWeb.TweetLive.Show do
  use XitterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Tweet <%= @tweet.id %>
      <:subtitle>This is a tweet record from your database.</:subtitle>

      <:actions>
        <.link patch={~p"/tweets/#{@tweet}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit tweet</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Id"><%= @tweet.id %></:item>

      <:item title="Content"><%= @tweet.content %></:item>
    </.list>

    <.back navigate={~p"/tweets"}>Back to tweets</.back>

    <.modal
      :if={@live_action == :edit}
      id="tweet-modal"
      show
      on_cancel={JS.patch(~p"/tweets/#{@tweet}")}
    >
      <.live_component
        module={XitterWeb.TweetLive.FormComponent}
        id={@tweet.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        tweet={@tweet}
        patch={~p"/tweets/#{@tweet}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:tweet, Ash.get!(Xitter.Tweets.Tweet, id, actor: socket.assigns.current_user))}
  end

  defp page_title(:show), do: "Show Tweet"
  defp page_title(:edit), do: "Edit Tweet"
end
