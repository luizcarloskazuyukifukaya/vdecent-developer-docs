# Installing the vdecent-app-deployment Skill

**🇧🇷 Português (Brasil):** [Ir para a seção em português](#instalação-da-skill-vdecent-app-deployment)

Place a copy (or symlink) of this folder into your harness's skills
directory. Each harness discovers a `SKILL.md` file in that directory.
Commands below run from the repository root; the skill directory is
`skills/vdecent-app-deployment`.

For the full step-by-step Git-beginner clone/install walkthrough, follow
**`skills/vdecent-app-development/INSTALL.md`** — installation is identical;
just replace `vdecent-app-development` with `vdecent-app-deployment`
wherever the folder name appears.

## Recommended: cross-harness location

`~/.agents/skills/` is the cross-runtime alias shared by Codex CLI, Gemini
CLI, and Copilot CLI, and is also read by other skill-capable harnesses.

```bash
ln -s "$PWD/skills/vdecent-app-deployment" ~/.agents/skills/vdecent-app-deployment
```

Prefer a copy if symlinks across filesystems are unreliable on your platform:

```bash
cp -r skills/vdecent-app-deployment ~/.agents/skills/vdecent-app-deployment
```

## Per-harness placement

| Harness | Skills directory (create if missing) |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex CLI | `~/.agents/skills/` (also `~/.codex/skills/`) |
| Gemini CLI | `~/.agents/skills/` (also `~/.gemini/skills/`) |
| Copilot CLI | `~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Google Antigravity | project/team skills in the Antigravity catalog |

Then restart/reload your agent so it picks up the newly installed skill.

## Updating

After pulling updates to this repository:

```bash
git pull
ln -sfT "$PWD/skills/vdecent-app-deployment" ~/.agents/skills/vdecent-app-deployment
```

---

## Instalação da Skill vdecent-app-deployment

**🇬🇧 English:** see the sections above.

Coloque uma cópia (ou symlink) desta pasta no diretório de skills do seu
harness. Cada harness descobre um arquivo `SKILL.md` nesse diretório.

```bash
# da raiz do repositório
ln -s "$PWD/skills/vdecent-app-deployment" ~/.agents/skills/vdecent-app-deployment
# ou, se symlink não funcionar:
cp -r skills/vdecent-app-deployment ~/.agents/skills/vdecent-app-deployment
```

Para instalação passo a passo para iniciantes em Git, siga o
**`skills/vdecent-app-development/INSTALL.md`** trocando o nome da pasta.

### Requisitos de ambiente

- GitHub: autenticação configurada para a conta/organização dos repositórios.
- App Manager API alcançável (`am-api-dev.v-decent.org` para
  desenvolvimento, `am-api.v-decent.org` para produção).
- Para checar o estado do deploy no Coolify, variável `COOLIFY_API_TOKEN`
  exportada no shell (usa `coolify.v-decent.org`).

Depois, reinicie/recarregue o agente para que ele carregue a skill.
