defmodule ScoutWeb.ManagementAuthControllerTest do
  use ScoutWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    {tmp_dir, token} = prepare_auth_file()

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{token: token}
  end

  test "redirects unauthenticated dashboard requests to login", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/login"
  end

  test "login page creates auth.txt when missing", %{conn: conn} do
    File.rm!(Scout.AuthTokens.path())

    conn = get(conn, ~p"/login")

    assert html_response(conn, 200) =~ "Access token"
    assert length(Scout.AuthTokens.tokens()) == 10
  end

  test "valid token login stores the session and allows dashboard access", %{
    conn: conn,
    token: token
  } do
    conn = post(conn, ~p"/login", %{"auth" => %{"token" => token}})

    assert redirected_to(conn) == ~p"/"

    conn = recycle(conn)
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Distributed Markdown fetch pipeline"
  end

  test "invalid token login renders the login page again", %{conn: conn} do
    conn = post(conn, ~p"/login", %{"auth" => %{"token" => "wrong-token"}})

    assert html_response(conn, 200) =~ "Invalid access token"
  end

  test "logout clears management access", %{conn: conn, token: token} do
    conn =
      conn
      |> init_test_session(%{management_token: token})
      |> delete(~p"/logout")

    assert redirected_to(conn) == ~p"/login"

    conn = recycle(conn)
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/login"
  end

  defp prepare_auth_file do
    previous_settings_path = Application.fetch_env!(:scout, :settings_path)
    tmp_dir = Path.join(System.tmp_dir!(), "scout-web-auth-#{System.unique_integer([:positive])}")
    settings_path = Path.join(tmp_dir, "settings.yaml")
    token = "test-management-token"

    File.mkdir_p!(tmp_dir)
    File.write!(settings_path, "general:\n  instance_name: Test Scout\n")
    Application.put_env(:scout, :settings_path, settings_path)
    File.write!(Path.join(tmp_dir, "auth.txt"), "#{token}\n")

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:scout, :settings_path, previous_settings_path)
    end)

    {tmp_dir, token}
  end
end
