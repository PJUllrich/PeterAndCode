defmodule AppWeb.Handlers.SesameSeedsPrice do
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu |> Map.put(:title, "Current Sesame Seeds Price:\n3,600 ugx/kg")
  end
end
