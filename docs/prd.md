Product Requirements Document (PRD) – SearchAggregator
Version: 1.3
Date: April 24, 2026
Status: Approved for implementation
Change Log: Requirement added to fully emulate SearXNG’s architecture, user experience, and configuration model (Section 1, 4 & 5). The app must behave like SearXNG (parallel engine querying, result merging, deduplication, privacy-first design) and use a single settings.yaml file for all runtime configuration.
1. Product Overview
SearchAggregator is an open-source, self-hosted metasearch engine designed to work exactly like SearXNG while being implemented natively in Elixir. It queries multiple external search providers in parallel, normalizes and deduplicates results, and delivers unified, privacy-respecting search results with zero tracking or profiling.
It replicates SearXNG’s core behavior: configurable engines, progressive result display, graceful degradation on engine failures, and a familiar user interface and settings model. Configuration is managed exclusively through a single settings.yaml file (loaded at runtime), making migration from SearXNG seamless for existing users and administrators.
2. Business & Product Goals

Deliver a drop-in Elixir replacement for SearXNG with identical user and admin experience.
Leverage Elixir’s concurrency and fault-tolerance while preserving SearXNG’s privacy-first philosophy and extensibility.
Enable easy configuration and engine management via settings.yaml (no Elixir code changes required for most customizations).
Support advanced stealth features (browser simulation + user browser data export) on top of SearXNG’s foundation.

3. Target Audience & User Personas

SearXNG Users / Migrators – expect identical behavior and settings.yaml compatibility.
Privacy Advocate – wants SearXNG-like privacy guarantees with improved performance and reliability.
Self-Hoster – needs simple YAML-based configuration and one-command deployment.
Developer Contributor – can add engines via YAML + minimal Elixir modules.

4. Core Features (MVP – Updated)

Real-time search interface with progressive result loading (SearXNG-style instant feedback).
Parallel querying of multiple search engines with per-engine timeouts and fallback behavior identical to SearXNG.
Automatic result normalization, deduplication by URL, and basic relevance scoring.
Browser Simulator Layer: Optional headless browser automation (Playwright-based) with per-engine mode selection.
Browser Data Exporter Script: Local tool to export user browser fingerprint data for improved stealth in simulator mode.
SearXNG-Compatible Configuration: All settings (enabled engines, engine-specific parameters, general preferences, timeouts, result limits, UI options, privacy settings) are defined in a single settings.yaml file loaded at runtime. Changes to YAML take effect immediately on restart or via hot-reload where possible.
Support for at least two initial engines, with clear path to full SearXNG parity (20+ engines configurable purely via YAML).
Modern, responsive UI using Phoenix LiveView that mirrors SearXNG’s layout and behavior.
Use of Elixir’s native lazy_html parser for all HTML-based engines.
Zero persistent logging of queries or results by default (configurable via YAML).

5. Non-Functional Requirements (Updated)

Configuration Model: Must use settings.yaml (YAML format) as the single source of truth for all runtime settings, exactly like SearXNG. Elixir config files are used only for build-time defaults.
Performance: Sub-10-second end-to-end response; browser simulation respects YAML-defined resource limits.
Reliability: Identical to SearXNG – partial results returned if some engines fail; supervised tasks prevent total failure.
Privacy & Security: All settings (including browser simulation toggles and data import paths) are controlled via YAML; exporter script remains 100% local.
Maintainability: Engine list, parameters, and preferences fully declarative in YAML; adding or disabling an engine requires no code changes.
Deployment: Docker image includes default settings.yaml; easy to override with mounted volume (SearXNG-style).
Compatibility: YAML schema designed to be as close as possible to SearXNG’s settings.yml for straightforward migration.

6. Out-of-Scope (Phase 1)

Full 1:1 reproduction of every SearXNG theme or plugin.
Persistent storage of exported browser profiles.
Automatic YAML hot-reload without restart (manual restart for MVP).

7. Success Metrics

Successful local deployment and search in under 5 minutes using a standard SearXNG-style settings.yaml.
At least 3 engines working with configuration driven entirely from YAML.
Users migrating from SearXNG report identical behavior and easier configuration.
