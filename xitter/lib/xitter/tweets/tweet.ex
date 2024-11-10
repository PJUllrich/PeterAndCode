defmodule Xitter.Tweets.Tweet do
  use Ash.Resource,
    otp_app: :xitter,
    domain: Xitter.Tweets,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "tweets"
    repo Xitter.Repo
  end

  actions do
    defaults [:read, update: [:content]]

    create :create do
      primary? true
      accept [:content]
      change relate_actor(:user)
    end

    update :set_content_to_fun do
      change atomic_update(:content, expr(fragment("'fun!'")))
    end
  end

  pub_sub do
    module XitterWeb.Endpoint
    prefix "tweets"
    publish_all :create, ["created"]
  end

  validations do
    validate string_length(:content, min: 10, max: 280)
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :content, :string do
      allow_nil? false
      public? true
      constraints trim?: false, allow_empty?: true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Xitter.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :user_email, :string, expr(user.email)
  end
end
