defmodule SearchAggregator.Search.BrowserSimulator do
  @moduledoc """
  Placeholder browser-mode adapter.

  The interface exists now so browser-only engines can be represented in
  `settings.yaml` without breaking the rest of the search pipeline.
  """

  def search(_module, _query, engine, settings, _opts) do
    if settings["browser_simulator"]["enabled"] do
      {:error,
       "#{engine["name"]} is configured for browser mode, but Playwright integration is not implemented yet"}
    else
      {:error, "#{engine["name"]} requires browser mode, but browser_simulator.enabled is false"}
    end
  end
end
