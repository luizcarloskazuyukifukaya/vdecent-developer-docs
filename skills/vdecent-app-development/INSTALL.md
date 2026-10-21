# Installing the vdecent-app-development Skill

**🇧🇷 Português (Brasil):** [Ir para a seção em português](#instalação-da-skill-vdecent-app-development)

Place a copy (or symlink) of this folder into your harness's skills
directory. Each harness discovers a `SKILL.md` file in that directory.
Commands below run from the repository root; the skill directory is
`skills/vdecent-app-development`.

Symlinking is recommended over copying so `git pull` keeps the skill
up to date.

## Getting the repository (clone)

These instructions assume you have never used Git or a "terminal/command
prompt" before. The goal of this step is to download a full copy (a
"clone") of this GitHub repository onto your computer so the
`skills/vdecent-app-development/` folder exists locally. All the later
commands in this file assume this folder is already on your machine.

1. Open a terminal:
   - **Linux/macOS:** open the "Terminal" app.
   - **Windows:** open "PowerShell" or "Command Prompt".
2. Pick a folder on your computer where the repository will live (for
   example, your home folder or a `projects/` folder). Go to it by typing:
   ```bash
   cd ~
   ```
   (`~` is a shortcut for your home folder; press `Enter` after typing.)
3. Make sure Git is installed. If it is not, your terminal will show a
   message like `git: command not found` — then install Git from
   https://git-scm.com/downloads and open a new terminal window.
4. Download the repository with this command (replace
   `vdecent-developer-docs` with the actual repository name if you were given
   a fork):
   ```bash
   git clone https://github.com/luizcarloskazuyukifukaya/vdecent-developer-docs.git
   ```
   After it finishes, a new folder called `vdecent-developer-docs/` appears in
   your current directory.
5. Move into the folder:
   ```bash
   cd vdecent-developer-docs
   ```
6. Confirm the skill folder exists:
   ```bash
   ls skills/vdecent-app-development/SKILL.md
   ```
   If you see `skills/vdecent-app-development/SKILL.md` listed (or no error),
   you have the files. From now on, "run from the repository root" below
   means running commands while you are inside this `vdecent-developer-docs`
   folder — the same folder you are in after step 5.

> **Getting updates later:** because you cloned, you can later download the
> newest version of the files from inside this folder with `git pull`. See
> the [Updating](#updating) section below.

## Recommended: cross-harness location

`~/.agents/skills/` is the cross-runtime alias shared by Codex CLI, Gemini
CLI, and Copilot CLI, and is also read by other skill-capable harnesses.
Installing there covers most tools at once.

```bash
ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/vdecent-app-development
```

Prefer a copy if symlinks across filesystems are unreliable on your platform:

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

---

# Instalação da Skill vdecent-app-development

> **English:** [Jump to the English version](#installing-the-vdecent-app-development-skill)

Coloque uma cópia (ou um symlink) desta pasta no diretório de skills do seu
harness. Cada harness descobre um arquivo `SKILL.md` nesse diretório.
Os comandos abaixo são executados a partir da raiz do repositório; o
diretório da skill é `skills/vdecent-app-development`.

Recomenda-se usar symlink em vez de cópia, assim o `git pull` mantém a skill
atualizada.

## Obtendo o repositório (clone)

Estas instruções assumem que você nunca usou Git ou um "terminal/prompt de
comando" antes. O objetivo deste passo é baixar uma cópia completa (um
"clone") deste repositório do GitHub para o seu computador, para que a pasta
`skills/vdecent-app-development/` exista localmente. Todos os comandos nas
seções seguintes presumem que essa pasta já está na sua máquina.

1. Abra um terminal:
   - **Linux/macOS:** abra o aplicativo "Terminal".
   - **Windows:** abra o "PowerShell" ou o "Prompt de Comando".
2. Escolha uma pasta do computador onde o repositório ficará (por exemplo, sua
   pasta pessoal ou uma pasta `projects/`). Vá até ela digitando:
   ```bash
   cd ~
   ```
   (`~` é um atalho para a sua pasta pessoal; pressione `Enter` depois de
   digitar.)
3. Verifique se o Git está instalado. Se não estiver, o terminal mostrará uma
   mensagem como `git: command not found` — então instale o Git em
   https://git-scm.com/downloads e abra uma nova janela de terminal.
4. Baixe o repositório com este comando (troque `vdecent-developer-docs`
   pelo nome real do repositório, se você recebeu um fork):
   ```bash
   git clone https://github.com/luizcarloskazuyukifukaya/vdecent-developer-docs.git
   ```
   Ao terminar, uma pasta nova chamada `vdecent-developer-docs/` aparece no
   seu diretório atual.
5. Entre na pasta:
   ```bash
   cd vdecent-developer-docs
   ```
6. Confirme que a pasta da skill existe:
   ```bash
   ls skills/vdecent-app-development/SKILL.md
   ```
   Se aparecer `skills/vdecent-app-development/SKILL.md` (ou nenhum erro),
   os arquivos estão com você. Daqui em diante, "executar a partir da raiz do
   repositório" abaixo significa executar comandos dentro desta pasta
   `vdecent-developer-docs` — a mesma pasta em que você está depois do passo
   5.

> **Recebendo atualizações depois:** como você clonou, poderá baixar a
> versão mais nova dos arquivos depois, de dentro desta pasta, com `git
> pull`. Veja a seção [Atualização](#atualização) abaixo.

## Local recomendado: caminho compartilhado entre harnesses

`~/.agents/skills/` é o alias compartilhado entre runtimes por Codex CLI,
Gemini CLI e Copilot CLI, e também é lido por outros harnesses com suporte a
skills. Instalar nesse local cobre a maioria das ferramentas de uma só vez.

```bash
ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/vdecent-app-development
```

Prefira uma cópia se symlinks entre filesystems forem não confiáveis na sua
plataforma:

```bash
cp -r skills/vdecent-app-development ~/.agents/skills/
```

## Instalação por harness

Execute a partir da raiz do repositório. Use a forma com symlink (`ln -s`)
ou com cópia (`cp -r`), conforme preferência.

| Harness | Diretório | Comando (forma com symlink) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/` (projeto: `.claude/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.claude/skills/` |
| Codex CLI | `~/.agents/skills/` ou `~/.codex/skills/` | `ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/` |
| Gemini CLI | `~/.gemini/skills/` (alias `~/.agents/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.gemini/skills/` |
| Copilot CLI | `~/.agents/skills/` | `ln -s "$PWD/skills/vdecent-app-development" ~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` (projeto: `.opencode/skills/`) | `ln -s "$PWD/skills/vdecent-app-development" ~/.config/opencode/skills/` |
| Google Antigravity | `<projeto>/.agents/skills/` (descoberta no workspace) | `ln -s "$PWD/skills/vdecent-app-development" <projeto>/.agents/skills/` |

Observações:
- O Antigravity descobre customizações em `.agents/` (ou `.agent/`,
  `_agents/`, `_agent/`) na raiz do projeto; por isso, crie o symlink dentro
  do projeto específico em que você trabalha.
- OpenCode, Claude Code e Codex também leem um diretório de skills com
  escopo de projeto (`.opencode/skills/`, `.claude/skills/`,
  `.codex/skills/`) — use a variante de projeto para manter a skill junto do
  repositório.

## Atualização

Após buscar commits mais recentes neste repositório, execute novamente o
comando de instalação apenas se você usou cópia (symlinks atualizam
automaticamente).

## Desinstalação

```bash
rm ~/.agents/skills/vdecent-app-development       # forma com symlink
rm -r ~/.agents/skills/vdecent-app-development    # forma com cópia
```

(Repita para o local em que você instalou.)
