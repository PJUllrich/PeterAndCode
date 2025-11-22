defmodule App.AccountsTest do
  use Support.DataCase

  alias App.Accounts

  describe "users" do
    @valid_attrs %{email: "some email"}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      user
    end

    test "get_user_by_email/1 returns a user with a given email" do
      user = user_fixture()
      assert %{email: "some email"} = Accounts.get_user_by_email(user.email)
    end
  end
end
