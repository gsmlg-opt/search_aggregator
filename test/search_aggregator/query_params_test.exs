defmodule SearchAggregator.QueryParamsTest do
  use ExUnit.Case, async: true

  alias SearchAggregator.Search.QueryParams

  test "parses searxng-style query params" do
    settings = %{
      "general" => %{"default_locale" => "en-US"},
      "search" => %{"result_limit" => 8, "max_limit" => 20},
      "ui" => %{"default_category" => "general"}
    }

    parsed =
      QueryParams.parse(
        %{
          "q" => "phoenix liveview",
          "categories" => "tech",
          "count" => "10",
          "engines" => "wikipedia,hacker_news",
          "language" => "zh-CN"
        },
        settings
      )

    assert parsed.query == "phoenix liveview"
    assert parsed.opts["category"] == "tech"
    assert parsed.opts["limit"] == 10
    assert parsed.opts["language"] == "zh-CN"
    assert parsed.opts["engine_names"] == MapSet.new(["wikipedia", "hacker_news"])
  end

  test "serializes only non-default params back to url state" do
    settings = %{
      "general" => %{"default_locale" => "en-US"},
      "search" => %{"result_limit" => 8},
      "ui" => %{"default_category" => "general"}
    }

    params =
      QueryParams.to_query_params(
        "phoenix",
        %{
          "category" => "tech",
          "limit" => 12,
          "engine_names" => MapSet.new(["hacker_news", "wikipedia"]),
          "language" => "zh-CN"
        },
        settings
      )

    assert params == %{
             "q" => "phoenix",
             "category" => "tech",
             "limit" => 12,
             "engines" => "hacker_news,wikipedia",
             "language" => "zh-CN"
           }
  end
end
