defmodule SearchAggregator.SearchTest do
  use ExUnit.Case, async: true

  alias SearchAggregator.Search
  alias SearchAggregator.Search.Result

  test "deduplicates results by normalized url and boosts merged score" do
    left = %Result{
      title: "Short",
      url: "https://example.com/path?a=1",
      engine: "wikipedia",
      score: 30
    }

    right = %Result{
      title: "Much Longer Title",
      url: "https://example.com/path",
      engine: "hn",
      score: 15
    }

    [merged] = Search.merge_results([left], [right], 10)

    assert merged.title == "Much Longer Title"
    assert merged.engine == "wikipedia, hn"
    assert merged.score == 70
  end

  test "filters enabled engines through yaml category tabs and explicit engine names" do
    settings = %{
      "ui" => %{
        "default_category" => "general",
        "categories_as_tabs" => %{"tech" => ["general", "tech"]}
      },
      "engines" => [
        %{
          "name" => "wikipedia",
          "engine" => "wikipedia",
          "categories" => ["general"],
          "disabled" => false
        },
        %{
          "name" => "hacker_news",
          "engine" => "hacker_news",
          "categories" => ["tech"],
          "disabled" => false
        },
        %{
          "name" => "disabled_engine",
          "engine" => "wikipedia",
          "categories" => ["general"],
          "disabled" => true
        }
      ]
    }

    engines =
      Search.enabled_engines(settings, %{
        "category" => "tech",
        "engine_names" => MapSet.new(["wikipedia", "hacker_news"])
      })

    assert Enum.map(engines, & &1["name"]) == ["wikipedia", "hacker_news"]
  end

  test "normalizes result limit against yaml max_limit" do
    settings = %{
      "general" => %{"default_locale" => "en-US"},
      "search" => %{"result_limit" => 8, "max_limit" => 12},
      "ui" => %{"default_category" => "general"}
    }

    opts = Search.normalize_options(%{"limit" => "999"}, settings)

    assert opts["limit"] == 12
    assert opts["category"] == "general"
  end
end
