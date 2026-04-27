# Settings Page Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add web UI settings management at `/settings` and `/settings/engines` with YAML persistence.

**Architecture:** Two LiveViews (SettingsLive for scalar settings, EngineSettingsLive for engine CRUD) backed by a new `Settings.save!/1` function on the existing GenServer. Both read `Settings.get()` in mount and persist via YAML write + reload.

**Tech Stack:** Phoenix LiveView 1.8, PhoenixDuskMoon components, YamlElixir

---

### Task 1: Add `save!/1` to Settings GenServer

**Files:**
- Modify: `apps/search_aggregator/lib/search_aggregator/settings.ex`
- Test: `apps/search_aggregator/test/search_aggregator/settings_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Add to apps/search_aggregator/test/search_aggregator/settings_test.exs
# Note: load_file!/1 and settings_path/0 are already public functions on Settings

@tag :tmp_dir
test "save!/1 persists settings to YAML and reloads", %{tmp_dir: tmp_dir} do
  path = Path.join(tmp_dir, "settings.yaml")
  settings = SearchAggregator.Settings.load_file!("test/support/fixtures/settings.yaml")
  modified = put_in(settings, ["general", "instance_name"], "Saved Test")

  # Write to tmp_dir to avoid mutating the committed fixture
  saved = SearchAggregator.Settings.save!(modified, path)

  assert saved["general"]["instance_name"] == "Saved Test"
  reloaded = SearchAggregator.Settings.load_file!(path)
  assert reloaded["general"]["instance_name"] == "Saved Test"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/search_aggregator/settings_test.exs:14`
Expected: FAIL with "function Settings.save!/1 is undefined"

- [ ] **Step 3: Implement `save!/1`**

```elixir
# Add to SearchAggregator.Settings module (apps/search_aggregator/lib/search_aggregator/settings.ex)

def save!(settings, path \\ nil) do
  GenServer.call(__MODULE__, {:save, settings, path})
end

# Add handle_call clause:
@impl true
def handle_call({:save, settings, path}, _from, state) do
  stripped = Map.delete(settings, "__meta__")
  target = path || settings_path()
  tmp = target <> ".tmp"

  :ok = YamlElixir.write_to_file!(tmp, stripped)
  File.rename!(tmp, target)

  new_state = load_settings!()
  {:reply, new_state, new_state}
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/search_aggregator/settings_test.exs`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add apps/search_aggregator/lib/search_aggregator/settings.ex apps/search_aggregator/test/search_aggregator/settings_test.exs
git commit -m "feat: add Settings.save!/1 for YAML persistence"
```

---

### Task 2: Add settings routes

**Files:**
- Modify: `apps/search_aggregator_web/lib/search_aggregator_web/router.ex`

- [ ] **Step 1: Add live routes**

```elixir
# Add inside the existing scope "/", SearchAggregatorWeb do ... pipe_through :browser block
live "/settings", SettingsLive, :index
live "/settings/engines", EngineSettingsLive, :index
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile`
Expected: warning about undefined modules (SettingsLive, EngineSettingsLive not yet created) — but compilation succeeds

- [ ] **Step 3: Commit**

```bash
git add apps/search_aggregator_web/lib/search_aggregator_web/router.ex
git commit -m "feat: add /settings and /settings/engines routes"
```

---

### Task 3: Add Settings nav link to Layouts

**Files:**
- Modify: `apps/search_aggregator_web/lib/search_aggregator_web/components/layouts.ex`

- [ ] **Step 1: Add Settings menu link**

Add a new `<:menu>` slot after the existing Home link:

```heex
<:menu>
  <.link navigate={~p"/settings"} class="text-primary-content/80 hover:text-primary-content">
    Settings
  </.link>
</:menu>
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile`
Expected: OK (may warn about SettingsLive not defined)

- [ ] **Step 3: Commit**

```bash
git add apps/search_aggregator_web/lib/search_aggregator_web/components/layouts.ex
git commit -m "feat: add Settings nav link to appbar"
```

---

### Task 4: Create SettingsLive (main settings page)

**Files:**
- Create: `apps/search_aggregator_web/lib/search_aggregator_web/live/settings_live.ex`
- Create: `apps/search_aggregator_web/test/search_aggregator_web/live/settings_live_test.exs`

- [ ] **Step 1: Create the test file**

```elixir
# apps/search_aggregator_web/test/search_aggregator_web/live/settings_live_test.exs
defmodule SearchAggregatorWeb.SettingsLiveTest do
  use SearchAggregatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the settings page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings")

    assert html =~ "Settings"
    assert html =~ "Instance Name"
    assert html =~ "Result Limit"
    assert html =~ "Save Settings"
  end

  test "renders form fields from current settings", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings")

    assert html =~ "SearchAggregator"
  end

  test "saves settings and shows success flash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html =
      view
      |> form("#settings-form", %{
        "settings" => %{
          "general" => %{
            "instance_name" => "MyTestInstance",
            "default_locale" => "en-US",
            "request_timeout_ms" => "1000",
            "contact_url" => ""
          },
          "search" => %{
            "result_limit" => "8",
            "max_limit" => "20",
            "autocomplete" => "off",
            "safe_search" => "0"
          },
          "ui" => %{
            "theme" => "dawn",
            "default_category" => "general",
            "categories_as_tabs" => "general:\n  - general"
          },
          "browser_simulator" => %{
            "enabled" => "false",
            "pool_size" => "2",
            "export_path" => ""
          }
        }
      })
      |> render_submit()

    assert html =~ "Settings saved"
  end

  test "shows validation errors for invalid fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html =
      view
      |> form("#settings-form", %{
        "settings" => %{
          "general" => %{
            "instance_name" => "",
            "default_locale" => "en-US",
            "request_timeout_ms" => "0",
            "contact_url" => ""
          },
          "search" => %{
            "result_limit" => "8",
            "max_limit" => "20",
            "autocomplete" => "off",
            "safe_search" => "0"
          },
          "ui" => %{
            "theme" => "dawn",
            "default_category" => "general",
            "categories_as_tabs" => "general:\n  - general"
          },
          "browser_simulator" => %{
            "enabled" => "false",
            "pool_size" => "2",
            "export_path" => ""
          }
        }
      })
      |> render_submit()

    assert html =~ "cannot be empty"
    assert html =~ "must be a positive integer"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/search_aggregator_web/live/settings_live_test.exs`
Expected: FAIL (SettingsLive module not found)

- [ ] **Step 3: Create SettingsLive**

```elixir
# apps/search_aggregator_web/lib/search_aggregator_web/live/settings_live.ex
defmodule SearchAggregatorWeb.SettingsLive do
  use SearchAggregatorWeb, :live_view

  alias SearchAggregator.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get()

    form =
      settings
      |> flatten_settings()
      |> to_form()

    {:ok, assign(socket, page_title: "Settings", form: form, settings: settings, errors: %{})}
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    errors = validate_settings(params)
    form = params |> to_form()
    {:noreply, assign(socket, form: form, errors: errors)}
  end

  @impl true
  def handle_event("save", %{"settings" => params}, socket) do
    errors = validate_settings(params)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, errors: errors)}
    else
      merged = unflatten_settings(params, socket.assigns.settings)

      try do
        Settings.save!(merged)
        {:noreply,
         socket
         |> put_flash(:info, "Settings saved.")
         |> assign(errors: %{})}
      rescue
        _ ->
          {:noreply, put_flash(socket, :error, "Failed to save settings.")}
      end
    end
  end

  defp validate_settings(params) do
    errors = %{}
    errors = if params["general"]["instance_name"] == "" or is_nil(params["general"]["instance_name"]),
      do: Map.put(errors, :"general[instance_name]", "cannot be empty"), else: errors

    errors = case Integer.parse(params["general"]["request_timeout_ms"] || "") do
      {n, _} when n > 0 -> errors
      _ -> Map.put(errors, :"general[request_timeout_ms]", "must be a positive integer")
    end

    errors = case Integer.parse(params["search"]["result_limit"] || "") do
      {n, _} when n > 0 -> errors
      _ -> Map.put(errors, :"search[result_limit]", "must be a positive integer")
    end

    errors = case Integer.parse(params["search"]["max_limit"] || "") do
      {n, _} when n > 0 -> errors
      _ -> Map.put(errors, :"search[max_limit]", "must be a positive integer")
    end

    errors
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <h1 class="text-3xl font-bold">Settings</h1>

        <.dm_form for={@form} id="settings-form" phx-change="validate" phx-submit="save">
          <.dm_form_section title="General">
            <.dm_form_grid>
              <.dm_input field={@form[:"general[instance_name]"]} label="Instance Name" errors={[@errors[:"general[instance_name]"]] |> Enum.reject(&is_nil/1)} />
              <.dm_input field={@form[:"general[default_locale]"]} label="Default Locale" />
              <.dm_input field={@form[:"general[request_timeout_ms]"]} label="Request Timeout (ms)" type="number" errors={[@errors[:"general[request_timeout_ms]"]] |> Enum.reject(&is_nil/1)} />
              <.dm_input field={@form[:"general[contact_url]"]} label="Contact URL" />
            </.dm_form_grid>
          </.dm_form_section>

          <.dm_form_section title="Search">
            <.dm_form_grid>
              <.dm_input field={@form[:"search[result_limit]"]} label="Result Limit" type="number" errors={[@errors[:"search[result_limit]"]] |> Enum.reject(&is_nil/1)} />
              <.dm_input field={@form[:"search[max_limit]"]} label="Max Limit" type="number" errors={[@errors[:"search[max_limit]"]] |> Enum.reject(&is_nil/1)} />
              <.dm_input field={@form[:"search[autocomplete]"]} label="Autocomplete" />
              <.dm_select
                field={@form[:"search[safe_search]"]}
                label="Safe Search"
                options={[{"0", "Off"}, {"1", "Moderate"}, {"2", "Strict"}]}
              />
            </.dm_form_grid>
          </.dm_form_section>

          <.dm_form_section title="UI">
            <.dm_form_grid>
              <.dm_input field={@form[:"ui[theme]"]} label="Theme" />
              <.dm_input field={@form[:"ui[default_category]"]} label="Default Category" />
              <.dm_textarea field={@form[:"ui[categories_as_tabs]"]} label="Categories as Tabs (YAML)" rows={6} />
            </.dm_form_grid>
          </.dm_form_section>

          <.dm_form_section title="Browser Simulator">
            <.dm_form_grid>
              <.dm_switch field={@form[:"browser_simulator[enabled]"]} label="Enabled" />
              <.dm_input field={@form[:"browser_simulator[pool_size]"]} label="Pool Size" type="number" />
              <.dm_input field={@form[:"browser_simulator[export_path]"]} label="Export Path" />
            </.dm_form_grid>
          </.dm_form_section>

          <:actions>
            <.dm_btn variant="ghost" navigate={~p"/"}>Cancel</.dm_btn>
            <.dm_btn variant="primary" type="submit" disabled={map_size(@errors) > 0}>Save Settings</.dm_btn>
          </:actions>
        </.dm_form>
      </div>
    </Layouts.app>
    """
  end

  defp flatten_settings(settings) do
    %{
      "general" => %{
        "instance_name" => settings["general"]["instance_name"],
        "default_locale" => settings["general"]["default_locale"],
        "request_timeout_ms" => settings["general"]["request_timeout_ms"],
        "contact_url" => settings["general"]["contact_url"]
      },
      "search" => %{
        "result_limit" => settings["search"]["result_limit"],
        "max_limit" => settings["search"]["max_limit"],
        "autocomplete" => settings["search"]["autocomplete"],
        "safe_search" => settings["search"]["safe_search"]
      },
      "ui" => %{
        "theme" => settings["ui"]["theme"],
        "default_category" => settings["ui"]["default_category"],
        "categories_as_tabs" => YamlElixir.write_to_string!(settings["ui"]["categories_as_tabs"])
      },
      "browser_simulator" => %{
        "enabled" => settings["browser_simulator"]["enabled"],
        "pool_size" => settings["browser_simulator"]["pool_size"],
        "export_path" => settings["browser_simulator"]["export_path"]
      }
    }
  end

  defp unflatten_settings(params, settings) do
    ui_categories =
      case YamlElixir.read_from_string(params["ui"]["categories_as_tabs"]) do
        {:ok, map} when is_map(map) -> map
        _ -> settings["ui"]["categories_as_tabs"]
      end

    %{
      "general" => %{
        "instance_name" => params["general"]["instance_name"],
        "default_locale" => params["general"]["default_locale"],
        "request_timeout_ms" => parse_int(params["general"]["request_timeout_ms"]),
        "contact_url" => params["general"]["contact_url"]
      },
      "search" => %{
        "result_limit" => parse_int(params["search"]["result_limit"]),
        "max_limit" => parse_int(params["search"]["max_limit"]),
        "autocomplete" => params["search"]["autocomplete"],
        "safe_search" => parse_int(params["search"]["safe_search"])
      },
      "ui" => %{
        "theme" => params["ui"]["theme"],
        "default_category" => params["ui"]["default_category"],
        "categories_as_tabs" => ui_categories
      },
      "browser_simulator" => %{
        "enabled" => params["browser_simulator"]["enabled"] == "true",
        "pool_size" => parse_int(params["browser_simulator"]["pool_size"]),
        "export_path" => params["browser_simulator"]["export_path"]
      },
      "engines" => settings["engines"]
    }
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> 0
    end
  end
end
```

- [ ] **Step 4: Add YamlElixir alias** — ensure `alias YamlElixir` or use fully-qualified calls. The code above uses `YamlElixir.write_to_string!` and `YamlElixir.read_from_string`.

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/search_aggregator_web/live/settings_live_test.exs`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add apps/search_aggregator_web/lib/search_aggregator_web/live/settings_live.ex apps/search_aggregator_web/test/search_aggregator_web/live/settings_live_test.exs
git commit -m "feat: add SettingsLive for web-based settings management"
```

---

### Task 5: Create EngineSettingsLive (engines page)

**Files:**
- Create: `apps/search_aggregator_web/lib/search_aggregator_web/live/engine_settings_live.ex`
- Create: `apps/search_aggregator_web/test/search_aggregator_web/live/engine_settings_live_test.exs`

- [ ] **Step 1: Create the test file**

```elixir
# apps/search_aggregator_web/test/search_aggregator_web/live/engine_settings_live_test.exs
defmodule SearchAggregatorWeb.EngineSettingsLiveTest do
  use SearchAggregatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the engines page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/engines")

    assert html =~ "Engines"
    assert html =~ "wikipedia"
    assert html =~ "Add Engine"
  end

  test "adds a new engine", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/engines")

    html =
      view
      |> element("#add-engine-btn")
      |> render_click()

    assert html =~ "Add Engine"

    html =
      view
      |> form("#engine-form", %{
        "engine" => %{
          "name" => "test_engine",
          "engine" => "test_engine",
          "shortcut" => "te",
          "mode" => "http",
          "base_url" => "https://example.com/search",
          "timeout_ms" => "3000",
          "categories" => "general, tech",
          "disabled" => "false"
        }
      })
      |> render_submit()

    assert html =~ "Engine saved"
  end

  test "removes an engine", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/engines")

    html =
      view
      |> element("button[data-confirm]")
      |> render_click()

    assert html =~ "Engine removed"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/search_aggregator_web/live/engine_settings_live_test.exs`
Expected: FAIL (EngineSettingsLive module not found)

- [ ] **Step 3: Create EngineSettingsLive**

```elixir
# apps/search_aggregator_web/lib/search_aggregator_web/live/engine_settings_live.ex
defmodule SearchAggregatorWeb.EngineSettingsLive do
  use SearchAggregatorWeb, :live_view

  alias SearchAggregator.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get()

    {:ok,
     assign(socket,
       page_title: "Engines",
       engines: settings["engines"],
       settings: settings,
       editing_engine: nil,
       show_add_modal: false
     )}
  end

  @impl true
  def handle_event("add_engine", _params, socket) do
    form =
      empty_engine()
      |> to_form(as: :engine)

    {:noreply, assign(socket, editing_engine: nil, show_add_modal: true, engine_form: form)}
  end

  @impl true
  def handle_event("edit_engine", %{"name" => name}, socket) do
    engine = Enum.find(socket.assigns.engines, &(&1["name"] == name))
    engine_map = engine |> Map.new(fn {k, v} -> {to_string(k), to_string(v)} end)

    form = engine_map |> to_form(as: :engine)

    {:noreply, assign(socket, editing_engine: name, show_add_modal: true, engine_form: form)}
  end

  @impl true
  def handle_event("save_engine", %{"engine" => params}, socket) do
    engine = %{
      "name" => params["name"],
      "engine" => params["engine"] || params["name"],
      "shortcut" => params["shortcut"],
      "mode" => params["mode"] || "http",
      "base_url" => params["base_url"],
      "timeout_ms" => parse_int(params["timeout_ms"]),
      "categories" => parse_categories(params["categories"]),
      "disabled" => params["disabled"] == "true"
    }

    engines =
      if socket.assigns.editing_engine do
        Enum.map(socket.assigns.engines, fn e ->
          if e["name"] == socket.assigns.editing_engine, do: engine, else: e
        end)
      else
        socket.assigns.engines ++ [engine]
      end

    save_engines(socket, engines)
    {:noreply,
     socket
     |> assign(engines: engines, show_add_modal: false, editing_engine: nil)
     |> put_flash(:info, "Engine saved.")}
  end

  @impl true
  def handle_event("delete_engine", %{"name" => name}, socket) do
    engines = Enum.reject(socket.assigns.engines, &(&1["name"] == name))
    save_engines(socket, engines)
    {:noreply, assign(socket, engines: engines) |> put_flash(:info, "Engine removed.")}
  end

  @impl true
  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, show_add_modal: false, editing_engine: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold">Engines</h1>
          <.dm_btn id="add-engine-btn" variant="primary" phx-click="add_engine">Add Engine</.dm_btn>
        </div>

        <div class="grid grid-cols-auto-fit-80 gap-6">
          <.dm_card :for={engine <- @engines}>
            <:title>{engine["name"]}</:title>
            <:action>
              <.dm_btn variant="ghost" size="sm" phx-click="edit_engine" phx-value-name={engine["name"]}>
                Edit
              </.dm_btn>
              <.dm_btn
                variant="error"
                size="sm"
                confirm={"Remove #{engine["name"]}?"}
                phx-click="delete_engine"
                phx-value-name={engine["name"]}
              >
                Remove
              </.dm_btn>
            </:action>
            <div class="space-y-2">
              <div class="flex flex-wrap gap-2">
                <.dm_badge variant="primary">{engine["mode"]}</.dm_badge>
                <span :if={engine["shortcut"]} class="text-sm text-on-surface-variant">
                  shortcut: {engine["shortcut"]}
                </span>
              </div>
              <p :if={engine["base_url"]} class="text-sm text-on-surface-variant truncate">
                {engine["base_url"]}
              </p>
              <div class="flex flex-wrap gap-1">
                <.dm_badge :for={cat <- engine["categories"]} variant="ghost">{cat}</.dm_badge>
              </div>
            </div>
          </.dm_card>
        </div>

        <.dm_card :if={@engines == []}>
          No engines configured. Click "Add Engine" to create one.
        </.dm_card>

        <.dm_modal :if={@show_add_modal} id="engine-modal">
          <:title>{if @editing_engine, do: "Edit Engine", else: "Add Engine"}</:title>
          <:body>
            <.dm_form for={@engine_form} id="engine-form" phx-submit="save_engine">
              <.dm_form_grid>
                <.dm_input field={@engine_form[:name]} label="Name" />
                <.dm_input field={@engine_form[:engine]} label="Engine Module" />
                <.dm_input field={@engine_form[:shortcut]} label="Shortcut" />
                <.dm_select
                  field={@engine_form[:mode]}
                  label="Mode"
                  options={[{"http", "HTTP"}, {"browser", "Browser"}]}
                />
                <.dm_input field={@engine_form[:base_url]} label="Base URL" />
                <.dm_input field={@engine_form[:timeout_ms]} label="Timeout (ms)" type="number" />
                <.dm_input field={@engine_form[:categories]} label="Categories (comma-separated)" />
                <.dm_switch field={@engine_form[:disabled]} label="Disabled" />
              </.dm_form_grid>
            </.dm_form>
          </:body>
          <:footer>
            <.dm_btn variant="ghost" phx-click="cancel_modal">Cancel</.dm_btn>
            <.dm_btn variant="primary" form="engine-form" type="submit">Save</.dm_btn>
          </:footer>
        </.dm_modal>
      </div>
    </Layouts.app>
    """
  end

  defp empty_engine do
    %{
      "name" => "",
      "engine" => "",
      "shortcut" => "",
      "mode" => "http",
      "base_url" => "",
      "timeout_ms" => "3000",
      "categories" => "",
      "disabled" => "false"
    }
  end

  defp save_engines(socket, engines) do
    settings = Map.put(socket.assigns.settings, "engines", engines)
    saved = Settings.save!(settings)
    # Update the socket's settings to the fresh state
    assign(socket, settings: saved)
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_categories(str) do
    str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/search_aggregator_web/live/engine_settings_live_test.exs`
Expected: Tests pass

- [ ] **Step 5: Run full test suite**

Run: `mix precommit`
Expected: All tests pass, format clean, no warnings

- [ ] **Step 6: Commit**

```bash
git add apps/search_aggregator_web/lib/search_aggregator_web/live/engine_settings_live.ex apps/search_aggregator_web/test/search_aggregator_web/live/engine_settings_live_test.exs
git commit -m "feat: add EngineSettingsLive for engine CRUD"
```

---

### Task 6: End-to-end verification

- [ ] **Step 1: Start the dev server and test manually**

Run: `mix phx.server`
Then: Visit http://localhost:6980/settings — verify form renders with current settings
Then: Visit http://localhost:6980/settings/engines — verify engine list renders
Then: Edit a setting, save, verify it persists
Then: Add/edit/remove an engine

- [ ] **Step 2: Run final precommit**

Run: `mix precommit`
Expected: Compile OK, format clean, all tests pass
