defmodule ScoutWeb.ManagementAuthController do
  use ScoutWeb, :controller

  alias ScoutWeb.ManagementAuth

  def new(conn, _params) do
    Scout.AuthTokens.ensure_file!()

    if ManagementAuth.authenticated?(conn) do
      redirect(conn, to: ~p"/")
    else
      render_new(conn)
    end
  end

  def create(conn, %{"auth" => %{"token" => token}}) when is_binary(token) do
    token = String.trim(token)

    if Scout.AuthTokens.valid_token?(token) do
      conn
      |> ManagementAuth.log_in(token)
      |> put_flash(:info, "Signed in")
      |> redirect(to: ~p"/")
    else
      conn
      |> put_flash(:error, "Invalid access token")
      |> render_new()
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid access token")
    |> render_new()
  end

  def delete(conn, _params) do
    conn
    |> ManagementAuth.log_out()
    |> put_flash(:info, "Signed out")
    |> redirect(to: ~p"/login")
  end

  defp render_new(conn) do
    Scout.AuthTokens.ensure_file!()

    render(conn, :new,
      page_title: "Management Login",
      form: Phoenix.Component.to_form(%{"token" => ""}, as: :auth)
    )
  end
end
