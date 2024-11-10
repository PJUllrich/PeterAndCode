defmodule XitterWeb.Router do
  use XitterWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XitterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", XitterWeb do
    pipe_through :browser

    # live "/tweets/:id/edit", TweetLive.Index, :edit

    # live "/tweets/:id/show/edit", TweetLive.Show, :edit

    ash_authentication_live_session :authenticated_routes do
      live "/tweets", TweetLive.Index, :index
      live "/tweets/new", TweetLive.Index, :new
      live "/tweets/:id", TweetLive.Show, :show
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {XitterWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {XitterWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {XitterWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/" do
    pipe_through :browser

    ash_admin("/admin")
  end

  scope "/", XitterWeb do
    pipe_through :browser

    get "/", PageController, :home

    auth_routes AuthController, Xitter.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{XitterWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    XitterWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth"
  end

  # Other scopes may use custom stacks.
  # scope "/api", XitterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:xitter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: XitterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
