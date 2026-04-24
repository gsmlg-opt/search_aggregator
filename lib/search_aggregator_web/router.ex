defmodule SearchAggregatorWeb.Router do
  use SearchAggregatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SearchAggregatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SearchAggregatorWeb do
    pipe_through :browser

    live "/", SearchLive, :index
  end

  scope "/search", SearchAggregatorWeb do
    pipe_through :api

    get "/", SearchAPIController, :index
  end
end
