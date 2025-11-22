defmodule App.UpdateUserAgeDomainService do
  use App, :domain_service

  alias App.{CountryAgePolicy, User}

  def update_age(user: %User{} = user, new_age: new_age) when is_integer(new_age) do
    minimun_age_requirement = CountryAgePolicy.get_policy(user.country_code_of_residence)

    case new_age >= minimun_age_requirement do
      true -> {:ok, User.update_age(user, new_age)}
      false -> {:error, :minimun_age_requirement_not_met}
    end
  end
end
