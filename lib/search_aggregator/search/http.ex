defmodule SearchAggregator.Search.HTTP do
  @moduledoc false

  def get_json(url, opts \\ []) do
    request_opts =
      Keyword.merge(
        [
          retry: false,
          headers: [{"accept", "application/json"}]
        ],
        opts
      )

    case Req.get(url, request_opts) do
      {:ok, %{body: body} = response} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, %{response | body: decoded}}
          {:error, reason} -> {:error, reason}
        end

      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
