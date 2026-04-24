defmodule SearchAggregatorWeb.SearchAPIController do
  use SearchAggregatorWeb, :controller

  alias SearchAggregator.Search
  alias SearchAggregator.Search.QueryParams

  def index(conn, params) do
    parsed = QueryParams.parse(params)
    query = parsed.query

    if query == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "q is required"})
    else
      search = Search.search(query, parsed.opts)

      json(conn, %{
        query: search.query,
        category: search.category,
        engines_selected: parsed_engine_names(search.opts),
        language: search.opts["language"],
        limit: search.opts["limit"],
        total_results: search.total_results,
        duration_ms: search.duration_ms,
        results: Enum.map(search.results, &Search.serialize_result/1),
        engines:
          Enum.map(search.engine_reports, fn report ->
            Map.take(report, [:engine, :mode, :ok?, :error, :duration_ms]) |> stringify_keys()
          end)
      })
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp parsed_engine_names(opts) do
    opts["engine_names"]
    |> Enum.sort()
  end
end
