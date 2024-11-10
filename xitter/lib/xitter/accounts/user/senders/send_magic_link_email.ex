defmodule Xitter.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use XitterWeb, :verified_routes

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists
    # if you get an email, the user does not exist yet
    # Example of how you might send this email
    # Xitter.Accounts.Emails.send_magic_link_email(
    #   user_or_email,
    #   token
    # )

    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    IO.puts("""
    Hello, #{email}! Click this link to sign in:

    #{url(~p"/auth/user/magic_link/?token=#{token}")}
    """)
  end
end
