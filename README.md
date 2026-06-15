# V-Decent Developer Documentation

This repository contains essential documentation and templates for developers building applications compatible with the **V-Decent Virtual Distributed Infrastructure (V-Decent)**.

## Objective

This repository provides guidelines and documentation for application developers to build, test, and deploy applications compatible with **V-Decent** infrastructure. These resources follow the **V3.0 Development Guidelines**.

## Available Resources

### 1. V-Decent Application Development Guide
**File:** `V-Decent Application Development Guide (en, V2_3).pdf`
A comprehensive manual covering:
- Docker Compose requirements.
- Native network isolation (external-tier vs. internal-tier).
- Port mapping restrictions.
- Persistence strategies and health checks.

### 2. V-Decent AI Agent Project Prompt
**File:** `v-decent-ai-agent-project-prompt_V2_3.md`
A pre-configured prompt template for AI coding agents (Gemini, Claude, Cursor, etc.). Using this prompt ensures your project structure and configuration are V-Decent compatible from the start.

## How to Use the AI Agent Prompt

1. Open `v-decent-ai-agent-project-prompt_V2_3.md`.
2. Replace the placeholders (e.g., `<APP_NAME>`, `<APP_SHORTNAME>`) with your specific project details.
3. Paste the entire content into your AI coding assistant as the initial system instruction or project briefing.

## V-Decent Compatibility Summary

- **Docker Compose:** Mandatory `docker-compose.yaml` at root.
- **No Host Port Mapping:** Use `expose` for internal networking.
- **Network Isolation:** Separate `external-tier` and `internal-tier`.
- **Labels:** Use `coolify.managed=true` for ingress routing.
- **Health Checks:** `/health` endpoint and Docker healthchecks for data services.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
