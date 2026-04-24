defmodule SearchAggregatorWeb.SearchLive do
  use SearchAggregatorWeb, :live_view

  alias SearchAggregator.Search
  alias SearchAggregator.Search.QueryParams
  alias SearchAggregator.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get()

    {:ok,
     assign(socket,
       page_title: "Search",
       query: "",
       category: settings["ui"]["default_category"],
       language: settings["general"]["default_locale"],
       selected_engines: MapSet.new(),
       settings: settings,
       results: [],
       engine_reports: [],
       search_ref: nil,
       pending_engines: 0,
       completed_engines: 0,
       result_limit: settings["search"]["result_limit"]
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    parsed = QueryParams.parse(params, socket.assigns.settings)

    {:noreply, apply_search(socket, parsed.query, parsed.opts, from_params?: true)}
  end

  @impl true
  def handle_event("search", %{"q" => raw_query}, socket) do
    opts = %{
      "category" => socket.assigns.category,
      "limit" => socket.assigns.result_limit,
      "engines" => socket.assigns.selected_engines,
      "language" => socket.assigns.language
    }

    {:noreply, push_patch(socket, to: ~p"/?#{QueryParams.to_query_params(raw_query, opts, socket.assigns.settings)}")}
  end

  @impl true
  def handle_event("set_category", %{"category" => category}, socket) do
    opts = current_opts(socket) |> Map.put("category", category)
    {:noreply, push_patch(socket, to: ~p"/?#{QueryParams.to_query_params(socket.assigns.query, opts, socket.assigns.settings)}")}
  end

  @impl true
  def handle_event("set_limit", %{"limit" => limit}, socket) do
    opts = current_opts(socket) |> Map.put("limit", limit)
    {:noreply, push_patch(socket, to: ~p"/?#{QueryParams.to_query_params(socket.assigns.query, opts, socket.assigns.settings)}")}
  end

  @impl true
  def handle_event("toggle_engine", %{"engine" => engine}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_engines, engine) do
        MapSet.delete(socket.assigns.selected_engines, engine)
      else
        MapSet.put(socket.assigns.selected_engines, engine)
      end

    opts = current_opts(socket) |> Map.put("engines", selected)
    {:noreply, push_patch(socket, to: ~p"/?#{QueryParams.to_query_params(socket.assigns.query, opts, socket.assigns.settings)}")}
  end

  defp apply_search(socket, query, opts, from_params?: _from_params?) do
    if query == "" do
      assign(socket,
        query: "",
        category: opts["category"],
        language: opts["language"],
        selected_engines: opts["engine_names"],
        results: [],
        engine_reports: [],
        search_ref: nil,
        pending_engines: 0,
        completed_engines: 0,
        result_limit: opts["limit"]
      )
    else
      run = Search.start(query, self(), opts)

      assign(socket,
        query: query,
        category: run.opts["category"],
        language: run.opts["language"],
        selected_engines: run.opts["engine_names"],
        results: [],
        engine_reports: [],
        search_ref: run.ref,
        pending_engines: run.total,
        completed_engines: 0,
        settings: run.settings,
        result_limit: run.opts["limit"]
      )
    end
  end

  @impl true
  def handle_info({:search_engine_result, ref, payload}, %{assigns: %{search_ref: ref}} = socket) do
    results =
      Search.merge_results(
        socket.assigns.results,
        payload.results,
        socket.assigns.result_limit
      )

    engine_reports =
      [payload | socket.assigns.engine_reports]
      |> Enum.sort_by(& &1.engine)

    {:noreply,
     assign(socket,
       results: results,
       engine_reports: engine_reports,
       completed_engines: socket.assigns.completed_engines + 1,
       pending_engines: max(socket.assigns.pending_engines - 1, 0)
     )}
  end

  def handle_info({:search_engine_result, _ref, _payload}, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <main class="search-page">
      <section class="hero">
        <p class="eyebrow">{@settings["general"]["instance_name"]}</p>
        <h1>SearXNG-style metasearch, implemented in Elixir.</h1>
        <p>
          Parallel engine execution, YAML-driven runtime configuration, graceful degradation,
          and privacy-first defaults. This first slice already queries multiple providers and
          merges results live as engines finish.
        </p>

        <.form for={%{}} as={:search} phx-submit="search" class="search-form">
          <div class="category-tabs">
            <button
              :for={{name, _targets} <- @settings["ui"]["categories_as_tabs"]}
              type="button"
              phx-click="set_category"
              phx-value-category={name}
              class={["tab-button", @category == name && "tab-button-active"]}
            >
              {humanize_category(name)}
            </button>
          </div>
          <div class="search-bar">
            <input
              class="search-input"
              type="text"
              name="q"
              value={@query}
              placeholder="Search without being profiled"
              autocomplete="off"
            />
            <button class="search-button" type="submit">Search</button>
          </div>
          <div class="control-row">
            <label class="control-block">
              <span class="eyebrow">Limit</span>
              <select class="control-select" phx-change="set_limit" name="limit">
                <option :for={limit <- [5, 8, 10, 20]} selected={@result_limit == limit} value={limit}>
                  {limit} results
                </option>
              </select>
            </label>
            <div class="control-block">
              <span class="eyebrow">Engines</span>
              <div class="engine-chips">
                <button
                  :for={engine <- available_engines(@settings, @category)}
                  type="button"
                  phx-click="toggle_engine"
                  phx-value-engine={engine["name"]}
                  class={[
                    "engine-chip",
                    (MapSet.size(@selected_engines) == 0 or MapSet.member?(@selected_engines, engine["name"])) &&
                      "engine-chip-active"
                  ]}
                >
                  {engine["name"]}
                </button>
              </div>
            </div>
          </div>
        </.form>
      </section>

      <section class="meta-strip">
        <article class="panel">
          <p class="eyebrow">Enabled Engines</p>
          <p class="metric">{active_engine_count(@settings, @category, @selected_engines)}</p>
        </article>
        <article class="panel">
          <p class="eyebrow">Category</p>
          <p class="metric">{humanize_category(@category)}</p>
        </article>
        <article class="panel">
          <p class="eyebrow">Progress</p>
          <p class="metric">{@completed_engines}/{@completed_engines + @pending_engines}</p>
        </article>
      </section>

      <section class="results-shell">
        <div class="results-list">
          <%= if @results == [] do %>
            <div class="panel empty-state">
              Results will appear here progressively as each engine responds.
            </div>
          <% else %>
            <article :for={result <- @results} class="result-card">
              <p class="eyebrow">{result.source}</p>
              <h2><a href={result.url} target="_blank" rel="noreferrer">{result.title}</a></h2>
              <p>{result.content}</p>
              <div class="result-meta">
                <span class="badge">{result.engine}</span>
                <span>{result.url}</span>
              </div>
            </article>
          <% end %>
        </div>

        <aside class="status-list">
          <article class="status-card">
            <p class="eyebrow">Config</p>
            <h3>{Path.basename(@settings["__meta__"]["path"])}</h3>
            <p>Runtime settings are loaded from YAML, not from compile-time Elixir config.</p>
            <div class="status-meta">
              <span>API: /search?q=phoenix</span>
              <span>Limit: {@result_limit}</span>
            </div>
          </article>

          <article :for={report <- @engine_reports} class="status-card">
            <p class="eyebrow">{report.engine}</p>
            <h3 class={if report.ok?, do: "status-ok", else: "status-error"}>
              {if report.ok?, do: "Completed", else: "Failed"}
            </h3>
            <p>{if report.ok?, do: "#{length(report.results)} results merged", else: report.error}</p>
            <div class="status-meta">
              <span>{report.mode}</span>
              <span>{report.duration_ms} ms</span>
            </div>
          </article>
        </aside>
      </section>
    </main>
    """
  end

  defp humanize_category(category) do
    category
    |> to_string()
    |> String.replace("_", " ")
    |> Phoenix.Naming.humanize()
  end

  defp current_opts(socket) do
    %{
      "category" => socket.assigns.category,
      "limit" => socket.assigns.result_limit,
      "engines" => socket.assigns.selected_engines,
      "language" => socket.assigns.language
    }
  end

  defp available_engines(settings, category) do
    Search.enabled_engines(settings, %{"category" => category, "engine_names" => MapSet.new()})
  end

  defp active_engine_count(settings, category, selected_engines) do
    Search.enabled_engines(settings, %{"category" => category, "engine_names" => selected_engines})
    |> length()
  end
end
