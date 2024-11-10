defmodule Xitter.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Xitter.Accounts.User, _opts) do
    Application.fetch_env(:xitter, :token_signing_secret)
  end
end
