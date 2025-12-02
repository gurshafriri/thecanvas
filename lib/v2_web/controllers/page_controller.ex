defmodule V2Web.PageController do
  use V2Web, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
