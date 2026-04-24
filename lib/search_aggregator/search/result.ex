defmodule SearchAggregator.Search.Result do
  @moduledoc false

  @enforce_keys [:title, :url, :engine]
  defstruct [:title, :url, :content, :engine, :source, :score, :published_at]
end
