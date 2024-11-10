defmodule Xitter.Tweets do
  use Ash.Domain

  resources do
    resource Xitter.Tweets.Tweet
  end
end
