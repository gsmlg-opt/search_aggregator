defmodule SearchAggregatorWeb.SearchAPIControllerTest do
  use SearchAggregatorWeb.ConnCase, async: true

  test "returns bad request when q is missing", %{conn: conn} do
    conn = get(conn, ~p"/search")

    assert json_response(conn, 400) == %{"error" => "q is required"}
  end

  test "returns normalized request metadata", %{conn: conn} do
    conn = get(conn, ~p"/search?q=phoenix&categories=general&count=5&engines=wikipedia")

    body = json_response(conn, 200)

    assert body["query"] == "phoenix"
    assert body["category"] == "general"
    assert body["limit"] == 5
    assert body["engines_selected"] == ["wikipedia"]
    assert is_integer(body["duration_ms"])
  end
end
