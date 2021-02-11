defmodule AppWeb.Handlers.MaizePrice.Nakuru do
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu |> Map.put(:title, "Current Maize price in Nakuru:\n2,400 ksh/90kg")
  end
end
