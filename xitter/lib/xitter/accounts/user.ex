defmodule Xitter.Accounts.User do
  use Ash.Resource,
    otp_app: :xitter,
    domain: Xitter.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshAdmin.Resource],
    data_layer: AshPostgres.DataLayer

  authentication do
    tokens do
      enabled? true
      token_resource Xitter.Accounts.Token
      signing_secret Xitter.Secrets
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true

        sender Xitter.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  postgres do
    table "users"
    repo Xitter.Repo
  end

  admin do
    actor?(true)
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type([:read, :update]) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:request_magic_link) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
