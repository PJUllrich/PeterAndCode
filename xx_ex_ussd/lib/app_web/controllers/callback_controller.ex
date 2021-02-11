defmodule AppWeb.CallbackController do
  use AppWeb, :controller

  alias AppWeb.Handlers.Home

  def callback(
        conn,
        %{"text" => text, "sessionId" => session_id, "serviceCode" => service_code} = request
      ) do
    menu = ExUssd.Menu.render(name: "Home", handler: Home)

    {:ok, response} =
      ExUssd.goto(
        internal_routing: %{text: text, session_id: session_id, service_code: service_code},
        menu: menu,
        api_parameters: request
      )

    send_resp(conn, 200, response)
  end
end
