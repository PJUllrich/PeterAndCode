defmodule AppWeb.Handlers.MaizePrice.Mombasa do
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu |> Map.put(:title, "Current Maize price in Mombasa:\n2,600 ksh/90kg")
  end
end
