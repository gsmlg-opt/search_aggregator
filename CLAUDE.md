# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Setup Dependencies:** `mix setup`
- **Start Development Server:** `mix phx.server` (or `iex -S mix phx.server` for an interactive shell)
- **Run All Tests:** `mix test`
- **Run a Specific Test:** `mix test path/to/file_test.exs` or `mix test path/to/file_test.exs:123` (to run a specific line)
- **Pre-commit Check (Compile, Format, Test):** `mix precommit` (Use this alias when you are done with all changes to catch warnings and run tests)

## Architecture & Structure

SearchAggregator is a Phoenix 1.8 application that queries multiple external search engines and aggregates the results, providing both an interactive UI and a JSON API.

- **`lib/search_aggregator/`** (Core Business Logic):
  - **`search.ex`**: The main context module for performing searches across engines.
  - **`search/engine.ex`**: The behaviour/contract that all search engine integrations must implement.
  - **`search/engines/`**: Individual provider implementations (e.g., Hacker News, Stack Overflow, Wikipedia).
  - **`search/http.ex`** & **`search/browser_simulator.ex`**: Network wrappers to fetch external results using the `Req` library.
  - **`settings.ex`**: Application settings and configuration management.
- **`lib/search_aggregator_web/`** (Web Interface):
  - **`live/search_live.ex`**: The Phoenix LiveView module serving the interactive search interface at `/`.
  - **`controllers/search_api_controller.ex`**: JSON API endpoint providing search results programmatically at `/search`.

## Project Guidelines

## UI Library

This project uses the DuskMoon UI system:

- **`phoenix_duskmoon`** — Phoenix LiveView UI component library (primary web UI)
- **`@duskmoon-dev/core`** — Core Tailwind CSS plugin and utilities
- **`@duskmoon-dev/css-art`** — CSS art utilities
- **`@duskmoon-dev/elements`** — Base web components
- **`@duskmoon-dev/art-elements`** — Art/decorative web components

Do NOT use DaisyUI or other CSS component libraries. Do NOT use `core_components.ex` — use `phoenix_duskmoon` components instead.
Use `@duskmoon-dev/core/plugin` as the Tailwind CSS plugin.

### Reporting issues or feature requests

If you encounter missing features, bugs, or need functionality not yet available in any DuskMoon package, open a GitHub issue in the appropriate repository with the label `internal request`:

- **`phoenix_duskmoon`** — https://github.com/gsmlg-dev/phoenix_duskmoon/issues
- **`@duskmoon-dev/core`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/css-art`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/elements`** — https://github.com/gsmlg-dev/duskmoon-dev/issues
- **`@duskmoon-dev/art-elements`** — https://github.com/gsmlg-dev/duskmoon-dev/issues

### Elixir Best Practices
- **HTTP Client:** Use the included `Req` library for HTTP requests. **Avoid** `:httpoison`, `:tesla`, and `:httpc`.
- **List Access:** Do not use index-based access syntax on lists (e.g., `mylist[i]` is invalid). Always use `Enum.at(mylist, i)`.
- **Variable Binding:** Elixir variables are immutable. For block expressions (`if`, `case`, `cond`), you must bind the *result* of the expression to a variable rather than rebinding inside the block.

### Phoenix v1.8 Conventions
- **LiveView Layouts:** Always begin LiveView templates with `<Layouts.app flash={@flash} ...>` to wrap all inner content.
- **Current Scope Assign:** If you see `current_scope` assign errors, move the routes to the proper `live_session` and pass `current_scope`.
- **Flash Messages:** Use DuskMoon flash components through `Layouts`; do not call legacy `<.flash_group>`.
- **UI Components:** Use `phoenix_duskmoon` components and helpers. Do not reintroduce `core_components.ex`.
