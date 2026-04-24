defmodule SearchAggregatorWeb.SearchLiveTest do
  use SearchAggregatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the search page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "SearXNG-style metasearch"
    assert html =~ "Search without being profiled"
  end

  test "restores search state from url params", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/?q=phoenix&category=tech&limit=5&engines=wikipedia")

    assert html =~ "value=\"phoenix\""
    assert html =~ "Tech"
    assert html =~ "5 results"
    assert html =~ "wikipedia"
  end
end
