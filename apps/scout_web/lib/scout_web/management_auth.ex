defmodule ScoutWeb.ManagementAuth do
  @moduledoc """
  Session-backed token authentication for Scout management UI routes.
  """

  import Phoenix.Controller
  import Plug.Conn

  use ScoutWeb, :verified_routes

  @session_key :management_token
  @session_name "management_token"

  def init(opts), do: opts

  def call(conn, _opts), do: require_authenticated_token(conn)

  def require_authenticated_token(conn) do
    if authenticated?(conn) do
      conn
    else
      conn
      |> delete_session(@session_key)
      |> put_flash(:error, "Log in with a token from auth.txt to access Scout.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def authenticated?(conn) do
    conn
    |> get_session(@session_key)
    |> Scout.AuthTokens.valid_token?()
  end

  def log_in(conn, token) do
    conn
    |> configure_session(renew: true)
    |> put_session(@session_key, String.trim(token))
  end

  def log_out(conn) do
    conn
    |> delete_session(@session_key)
    |> configure_session(renew: true)
  end

  def on_mount(:default, _params, session, socket) do
    if valid_session?(session) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/login")}
    end
  end

  defp valid_session?(session) do
    session
    |> session_token()
    |> Scout.AuthTokens.valid_token?()
  end

  defp session_token(session) do
    Map.get(session, @session_name) || Map.get(session, @session_key)
  end
end
