defmodule AppWeb.Handlers.MaizePrice.Nairobi do
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu |> Map.put(:title, "Current Maize price in Nairobi:\n2,500 ksh/90kg")
  end
end
