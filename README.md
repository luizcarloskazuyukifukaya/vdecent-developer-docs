# V-Decent Developer Documentation

This repository contains essential documentation and templates for developers building applications compatible with the **V-Decent Virtual Distributed Infrastructure (V-Decent)**.

## Objective

This repository provides guidelines and documentation for application developers to build, test, and deploy applications compatible with **V-Decent** infrastructure. These resources follow the **V3.1 Development Guidelines**, as defined in the V-Decent Application Development Guide PDF included in this repository.

## Available Resources

### 1. V-Decent Application Development Guide
**File:** `V-Decent Application Development Guide (en, V3_1).pdf`
A comprehensive manual covering:
- Docker Compose requirements.
- Network limitations (avoiding custom network definitions).
- Port mapping restrictions.
- Persistence strategies and health checks.

### 2. V-Decent AI Agent Project Prompt
**File:** `v-decent-ai-agent-project-prompt_V3_2.md`
A pre-configured prompt template for AI coding agents (Gemini, Claude, Cursor, etc.). Using this prompt ensures your project structure and configuration are V-Decent compatible from the start. It includes the non-negotiable rules, a required pre-registration validation script, and an acceptance-criteria checklist the agent must satisfy before you register the app.

## How to Use the AI Agent Prompt (Prompt Engineering Guide)

This document is written to be pasted whole, not summarized. It is designed as a **system/briefing prompt** — the Non-Negotiable Rules, the rationalization tables, and the validation steps only work if the agent sees the exact wording, not your paraphrase of it. Summarizing it defeats the purpose: the rules exist specifically because agents rationalize their way past a plain instruction, and a summary strips the counter-argument that stops that.

### Starting a new project

1. Open `v-decent-ai-agent-project-prompt_V3_2.md`.
2. Fill in the placeholders in the **"Application to Deploy in V-Decent"** section (`<APP_NAME>`, `<APP_SHORTNAME>`, `<STATELESS | STATEFUL_EXTERNAL_DATA | ...>`, etc.) with your project's actual details. Leave the rest of the document unedited — it is generic to all V-Decent apps.
3. Paste the **entire file** into your AI coding assistant (Claude Code, Codex, Gemini CLI, Cursor, etc.) as the first message or system/project instruction, before asking it to write any code.
4. Ask the agent to restate which **Application Pattern (A/B/C)** it selected and why, before it starts generating files — this confirms it actually read the Supported Application Types section rather than defaulting to a guess.

### Keeping an agent compliant mid-project

Agents drift over long sessions, especially once other frameworks' conventions (host `ports:`, custom `networks:`) reassert themselves as "best practice." If you see a generated `docker-compose.yaml` with a `networks:` section or a `ports:` mapping:

- Don't just say "remove that" — re-paste the specific rule section (2 or 3) including its rationalization table. The table names the exact excuse the agent is likely reaching for and states why it doesn't apply here; a bare correction tends to get re-introduced a few turns later.
- Before accepting the work as done, explicitly ask the agent to run through the **Acceptance Criteria** checklist and the **Pre-Registration Compatibility Validation** section (running `validate-vdecent-compat.sh` against `docker-compose.yaml` alone, plus the no-override-files smoke test) and report the result of each item. A local `docker compose up` succeeding is not sufficient evidence — it will pass even when the file still contains a forbidden key that App Manager will reject.
- If the agent claims "done," ask it to paste the actual checklist with each box checked and the validation script's output, rather than taking a verbal confirmation.

### Updating an existing V-Decent app

You can also re-paste just the relevant rule section (e.g. Non-Negotiable Rules, or the Local Development Setup section) when asking an agent to modify an existing app, instead of the whole document — useful for smaller, targeted changes where a full re-briefing is overkill.

## V-Decent Compatibility Summary

- **Docker Compose:** Mandatory `docker-compose.yaml` at root.
- **No Host Port Mapping:** Use `expose` for internal networking only.
- **CRITICAL: No Network Definitions:** Do **not** define custom networks or a `networks:` section in `docker-compose.yaml`. This is a limitation to ensure compatibility with V-Decent proxy routing.
- **Labels:** The `coolify.managed=true` label is **required** on the public-facing service.
- **Health Checks:** Applications must provide a `/health` endpoint and use Docker healthchecks for data services.
- **Pre-Registration Validation:** Run `validate-vdecent-compat.sh` against `docker-compose.yaml` alone (no dev/local overrides) before registering with App Manager — a successful local `docker compose up` does not guarantee App Manager compatibility, since local override files can mask a forbidden `networks:`/`ports:` entry still present in the base manifest.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
