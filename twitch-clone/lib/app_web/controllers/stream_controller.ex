defmodule AppWeb.StreamController do
  use AppWeb, :controller

  def show(conn, %{"file" => filename}) do
    file = File.read!("./tmp/stream/#{filename}")

    conn =
      if String.ends_with?(filename, ".m3u8") do
        put_resp_content_type(conn, "application/vnd.apple.mpegurl")
      else
        conn
        # put_resp_content_type(conn, "video/mp4")
      end

    # file =
    #   if filename != "index.m3u8" && String.ends_with?(filename, ".m3u8") do
    #     offset = "#EXT-X-START:TIME-OFFSET=-1,PRECISE=NO"
    #     event_type = "#EXT-X-PLAYLIST-TYPE:EVENT"
    #     [line | rest] = String.split(file, "\n")
    #     Enum.join([line, offset, event_type] ++ rest, "\n")
    #   else
    #     file
    #   end

    send_resp(conn, 200, file)
  end
end
