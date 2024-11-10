defmodule Xitter.Accounts do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource Xitter.Accounts.Token

    resource Xitter.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
    end
  end
end
