defmodule ScoutWeb.Router do
  use ScoutWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ScoutWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :management_auth do
    plug ScoutWeb.ManagementAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ScoutWeb do
    pipe_through :browser

    get "/login", ManagementAuthController, :new
    post "/login", ManagementAuthController, :create
    delete "/logout", ManagementAuthController, :delete
  end

  scope "/", ScoutWeb do
    pipe_through [:browser, :management_auth]

    live_session :management, on_mount: ScoutWeb.ManagementAuth do
      live "/", DashboardLive, :index
    end
  end

  scope "/api", ScoutWeb do
    pipe_through :api

    post "/fetch", FetchController, :create
    post "/fetch/sync", FetchController, :sync
    get "/fetch/:job_id", FetchController, :show
  end
end
