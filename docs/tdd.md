Updated Technical Design Document (TDD) – SearchAggregator
Version: 1.3
Date: April 24, 2026
Change Log: Requirement added to emulate SearXNG architecture and mandate settings.yaml as the central configuration file (Sections 1, 4 & 5).
1. Architecture Overview
SearchAggregator is architected to mirror SearXNG’s design while leveraging Elixir’s strengths:
User Layer → Phoenix LiveView (SearXNG-like UI with real-time updates)
Application Layer → SearchAggregator.Search (orchestrator)
Engine Layer → Pluggable Engine modules (behaviour-driven)
Browser Simulation Layer → Headless browser pool with user-data support
Configuration Layer → Runtime YAML loader (new)
HTTP / Parsing Layer → Req + lazy_html
Data Layer → In-memory Result structs
The system centers on parallel supervised Tasks, with all runtime behavior driven by a single settings.yaml file.
2. Key Design Principles (Updated)

SearXNG Parity: Identical high-level behavior – parallel queries, result merging, deduplication, graceful degradation, and privacy model.
YAML-Driven Configuration: settings.yaml is the single source of truth for engines, general settings, timeouts, privacy options, and browser simulator preferences (loaded at startup via runtime YAML parser).
Behaviour-Driven Engines: Engines implement the Engine contract; their enabled state, parameters, and mode (HTTP or browser) are declared in YAML.
Privacy by Design: All configuration options (including browser data paths) are explicit in YAML; no hidden defaults.
Fault Tolerance: Supervised Tasks with YAML-defined timeouts.
Progressive Enhancement: LiveView streams results exactly as in SearXNG.

3. High-Level Data Flow (Updated)

On startup, the application loads and validates settings.yaml.
User optionally exports browser data locally and references the file path in YAML.
User submits query via LiveView.
Search orchestrator reads enabled engines and their parameters from the loaded YAML config.
Parallel Tasks are spawned per enabled engine (respecting YAML timeouts and modes).
Browser-mode engines receive imported data (if specified in YAML) from the simulator pool.
Results are normalized, deduplicated by URL, scored, and returned.
LiveView updates UI in real time, matching SearXNG’s progressive display.

4. Core Components & Responsibilities (Updated)

Engine Behaviour: Defines search/2; YAML controls which engines are active and their runtime parameters.
Result Struct: Unchanged.
Search Aggregator: Reads engine list and settings directly from loaded YAML at runtime.
Configuration Loader (new): Dedicated module that parses settings.yaml on startup (or on reload), validates schema, and exposes settings to the rest of the application. Supports SearXNG-compatible structure for engines, general, and ui sections.
Browser Simulator Layer: Respects YAML settings for pool size, enabled engines, and path to user-exported browser data JSON.
LiveView: UI settings (result count, layout, etc.) pulled from YAML.
Engines Folder: Modules are lightweight; all configuration (enable/disable, timeouts, browser mode) lives in YAML.

5. Technology Stack (Updated)

Language & Framework: Elixir + Phoenix 1.7+.
HTML Parsing: lazy_html (Lexbor-based).
Browser Simulation: Playwright via Elixir binding.
Configuration: YAML loaded at runtime (using a stable Elixir YAML library); schema mirrors SearXNG’s settings.yml for compatibility.
No Database: In-memory only.

6. Extensibility & Future Considerations

New engines added by creating a module and enabling it in settings.yaml (no code changes to core).
YAML schema extensible for future SearXNG features (themes, plugins, advanced privacy toggles).
Hot-reload of settings.yaml can be added in future releases.

7. Risks & Mitigations (Updated)

YAML schema divergence from SearXNG: Mitigated by designing the loader to support SearXNG’s exact structure where possible.
Configuration complexity: Mitigated by providing a well-documented default settings.yaml with comments mirroring SearXNG.
Privacy leakage via config: Mitigated by clear YAML documentation of every option and default privacy-safe values.