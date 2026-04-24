defmodule SearchAggregator.Search.Engine do
  @moduledoc false

  alias SearchAggregator.Search.Result

  @callback search(binary(), map(), map()) :: {:ok, [Result.t()]} | {:error, term()}
end
