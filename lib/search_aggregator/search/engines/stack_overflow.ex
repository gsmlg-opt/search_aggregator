defmodule SearchAggregator.Search.Engines.StackOverflow do
  @moduledoc false

  @behaviour SearchAggregator.Search.Engine

  alias SearchAggregator.Search.HTTP
  alias SearchAggregator.Search.Result

  @impl true
  def search(query, engine, settings) do
    params = [
      order: "desc",
      sort: "relevance",
      site: "stackoverflow",
      pagesize: settings["search"]["result_limit"],
      intitle: query
    ]

    case HTTP.get_json(engine["base_url"], params: params, receive_timeout: engine["timeout_ms"]) do
      {:ok, %{status: 200, body: %{"items" => items}}} ->
        results =
          items
          |> Enum.with_index()
          |> Enum.map(fn {item, index} ->
            %Result{
              title: item["title"],
              url: item["link"],
              content: snippet(item),
              engine: engine["name"],
              source: "Stack Overflow",
              score: 100 - index,
              published_at: published_at(item["creation_date"])
            }
          end)

        {:ok, results}

      {:ok, %{status: status}} ->
        {:error, "unexpected response status #{status}"}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end

  defp snippet(item) do
    tags = Enum.join(item["tags"] || [], ", ")
    score = item["score"] || 0
    answers = item["answer_count"] || 0

    "Tags: #{tags} • Score: #{score} • Answers: #{answers}"
  end

  defp published_at(unix) when is_integer(unix),
    do: DateTime.from_unix!(unix) |> DateTime.to_iso8601()

  defp published_at(_), do: nil
end
