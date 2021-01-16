defmodule App do
  @moduledoc """
  App keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  When used, dispatch to the appropriate domain_model/repository/etc.
  """
  def domain_model do
    quote do
      @self __MODULE__
      use Ecto.Schema
    end
  end

  def domain_service do
    quote do
    end
  end

  def application_service do
    quote do
      alias App.Repo
    end
  end

  def repository do
    quote do
      alias App.Repo
      import Ecto.Query, warn: false
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
