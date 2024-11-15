defmodule FluxWeb.PageLive do
  use FluxWeb, :live_view

  @impl true
  def handle_event("alert", _parms, socket) do
    {:noreply,
     socket
     |> put_toast(:info, "Alert")
     |> put_flash(Enum.random([:error, :info]), "Alert! Alert! Alert!")}
  end
end
