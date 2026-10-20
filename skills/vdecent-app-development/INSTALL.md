# Installing the vdecent-app-development Skill

Place a copy (or symlink) of this folder into your harness's skills
directory. Each harness discovers a `SKILL.md` file in that directory.
Commands below run from the repository root; the skill directory is
`skills/vdecent-app-development`.

Symlinking is recommended over copying so `git pull` keeps the skill
up to date.

## Recommended: cross-harness location

`~/.agents/skills/` is the cross-runtime alias shared by Codex CLI, Gemini
CLI, and Copilot CLI, and is also read by other skill-capable harnesses.
Installing there covers most tools at once.

```bash
ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/vdecent-app-development
```

Prefer a copy if symlinks are unreliable on your platform:

```bash
cp -r skills/vdecent-app-development ~/.agents/skills/
```

## Per-harness placement

Run from the repository root. Substitute the symlink (`ln -s`) or the copy
(`cp -r`) form as preferred.

| Harness | Location | Command (symlink form) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/` (project: `.claude/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.claude/skills/` |
| Codex CLI | `~/.agents/skills/` or `~/.codex/skills/` | `ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/` |
| Gemini CLI | `~/.gemini/skills/` (alias `~/.agents/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.gemini/skills/` |
| Copilot CLI | `~/.agents/skills/` | `ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` (project: `.opencode/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.config/opencode/skills/` |
| Google Antigravity | `<project>/.agents/skills/` (workspace discovery) | `ln -s "$PWD/skills/vdecent-app-development" <project>/.agents/skills/` |

Notes:
- Antigravity discovers customizations from `.agents/` (or `.agent/`,
  `_agents/`, `_agent/`) at the project root, so symlink into the specific
  project you work in.
- OpenCode, Claude Code, and Codex also read a project-scoped skill
  directory (`.opencode/skills/`, `.claude/skills/`, `.codex/skills/`) — use
  the project variant to keep the skill with the repository.

## Updating

After pulling newer commits in this repository, re-run the installation
command only if you copied (symlinks update automatically).

## Uninstalling

```bash
rm ~/.agents/skills/vdecent-app-development       # symlink form
rm -r ~/.agents/skills/vdecent-app-development    # copy form
```

(Repeat for whichever location you installed to.)