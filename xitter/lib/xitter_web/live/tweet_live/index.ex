defmodule XitterWeb.TweetLive.Index do
  use XitterWeb, :live_view

  on_mount {XitterWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Tweets
      <:actions>
        <.link patch={~p"/tweets/new"}>
          <.button>New Tweet</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="tweets"
      rows={@streams.tweets}
      row_click={fn {_id, tweet} -> JS.navigate(~p"/tweets/#{tweet}") end}
    >
      <%!-- <:col :let={{_id, tweet}} label="Id"><%= tweet.id %></:col> --%>

      <:col :let={{_id, tweet}} label="Content"><%= tweet.content %></:col>
      <:col :let={{_id, tweet}} label="Email"><%= tweet.user_email %></:col>

      <%!-- <:action :let={{_id, tweet}}>
        <div class="sr-only">
          <.link navigate={~p"/tweets/#{tweet}"}>Show</.link>
        </div>

        <.link patch={~p"/tweets/#{tweet}/edit"}>Edit</.link>
      </:action> --%>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="tweet-modal"
      show
      on_cancel={JS.patch(~p"/tweets")}
    >
      <.live_component
        module={XitterWeb.TweetLive.FormComponent}
        id={(@tweet && @tweet.id) || :new}
        title={@page_title}
        current_user={@current_user}
        action={@live_action}
        tweet={@tweet}
        patch={~p"/tweets"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xitter.PubSub, "tweets:created")
    end

    {:ok,
     socket
     |> stream(
       :tweets,
       Ash.read!(Xitter.Tweets.Tweet, actor: socket.assigns[:current_user], load: [:user_email])
     )
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "tweets:created", payload: payload},
        socket
      ) do
    {:noreply, insert_tweet(socket, payload.data)}
  end

  @impl true
  def handle_info({XitterWeb.TweetLive.FormComponent, {:saved, tweet}}, socket) do
    {:noreply, insert_tweet(socket, tweet)}
  end

  # defp apply_action(socket, :edit, %{"id" => id}) do
  #   socket
  #   |> assign(:page_title, "Edit Tweet")
  #   |> assign(:tweet, Ash.get!(Xitter.Tweets.Tweet, id, actor: socket.assigns.current_user))
  # end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Tweet")
    |> assign(:tweet, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Tweets")
    |> assign(:tweet, nil)
  end

  defp insert_tweet(socket, tweet) do
    tweet = Ash.load!(tweet, [:user_email])
    stream_insert(socket, :tweets, tweet, at: 0)
  end
end
