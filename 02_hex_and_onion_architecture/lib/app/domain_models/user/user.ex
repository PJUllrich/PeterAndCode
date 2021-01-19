defmodule App.User do
  use App, :domain_model

  schema "users" do
    field :age, :integer
    field :country_code_of_residence, :string
  end

  def new(age: age, country_code_of_residence: country_code_of_residence) do
    user =
      %@self{}
      |> set_country_code_of_residence(country_code_of_residence)
      |> set_age(age)

    {:ok, user}
  end

  def update_age(%@self{} = user, new_age) do
    {:ok, set_age(user, new_age)}
  end

  defp set_country_code_of_residence(%@self{} = user, country_code_of_residence)
       when country_code_of_residence in ["usa", "ger", "aus"] do
    %@self{user | country_code_of_residence: country_code_of_residence}
  end

  defp set_age(%@self{} = user, age) when is_integer(age) do
    %@self{user | age: age}
  end
end
