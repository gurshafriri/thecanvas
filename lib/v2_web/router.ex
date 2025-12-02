defmodule V2Web.Router do
  use V2Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {V2Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", V2Web do
    pipe_through :browser

    live "/", JamLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", V2Web do
  #   pipe_through :api
  # end
end
