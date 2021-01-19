defmodule App.CountryAgePolicy do
  use App, :domain_model

  @policies %{
    "usa" => 21,
    "ger" => 18,
    "aus" => 16
  }

  def get_policy(country_code) do
    Map.get(@policies, country_code)
  end
end
