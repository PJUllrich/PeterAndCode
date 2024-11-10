defmodule App.WebSocket do
  use WebSockex

  require Logger

  # @url "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos"
  @url "wss://jetstream.atproto.tools/subscribe\?wantedCollections=app.bsky.feed.post"

  # Public Functions

  def start_link(_args) do
    WebSockex.start_link(@url, __MODULE__, [])
  end

  # Callbacks

  def handle_frame(event, buffer) do
    App.Buffer.insert_event(event)
    {:ok, buffer}
  end
end
