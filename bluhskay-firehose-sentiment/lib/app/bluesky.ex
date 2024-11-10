defmodule App.Bluesky do
  @posts_url "https://public.api.bsky.app/xrpc/app.bsky.feed.getPosts?"
  def get_posts(uris) do
    param = Plug.Conn.Query.encode(%{"uris[]" => uris})
    Req.get(@posts_url <> param)
  end
end
