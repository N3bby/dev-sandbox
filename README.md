# dev-sandbox

Drops you into a throwaway dev environment with the current directory mounted, using an image/template definition pulled from this repo. Two commands are available:

- **`dev`** — runs each session inside a Docker *Sandbox* (`sbx`). Assets live under [`docker-sandbox/`](docker-sandbox).
- **`dev-container`** — runs a plain `docker run` container as the host user (via `gosu`), so files created inside don't end up root-owned on the host. Assets live under [`docker-container/`](docker-container).

Both share this repo, the installer, and self-update on each run. Pick `dev` if you have `sbx` installed; `dev-container` needs only Docker.

## Install

```bash
git clone git@github.com:n3bby/dev-sandbox.git ~/.dev-sandbox && bash ~/.dev-sandbox/install.sh
```

Then add to your `.bashrc` or `.zshrc`:

```bash
export PATH="$HOME/.dev-sandbox/bin:$PATH"
```

## Update

Both commands pull the latest changes automatically on each run — no manual update needed.

## Uninstall

```bash
bash ~/.dev-sandbox/uninstall.sh
```

## Configuration (`dev-container`)

The `dev-container` method's optional mounts are configured in `~/.dev-sandbox/docker-container/mounts` — one entry per line:

```
source:target[:opts]
```

```
# comments and blank lines are ignored
/var/run/docker.sock:/var/run/docker.sock
# ~/.ssh/id_rsa:/home/ubuntu/.ssh/id_rsa:ro
# ~/.ssh/id_rsa.pub:/home/ubuntu/.ssh/id_rsa.pub:ro
~/.gitconfig:/home/ubuntu/.gitconfig:ro
~/.dev-sandbox/docker-container/agents/claude/config:/home/ubuntu/.claude:mkdir
~/.dev-sandbox/docker-container/agents/claude/claude.json:/home/ubuntu/.claude.json:json
~/.dev-sandbox/docker-container/agents/opencode/config:/home/ubuntu/.config/opencode:mkdir
~/.dev-sandbox/docker-container/agents/opencode/data:/home/ubuntu/.local/share/opencode:mkdir
~/.dev-sandbox/docker-container/agents/opencode/state:/home/ubuntu/.local/state/opencode:mkdir
~/.dev-sandbox/docker-container/agents/opencode/cache:/home/ubuntu/.cache/opencode:mkdir
```

`opts` can be:

- `ro` — mount the path read-only.
- `mkdir` — create the source as a directory on the host if it's missing.
- `touch` — create the source as an empty file on the host if it's missing.
- `json` — like `touch`, but seed the file with `{}` (and re-seed it if it already exists but is empty). Use this for tools like Claude Code that fail to start on an empty file where they expect JSON.

Without `mkdir`/`touch`/`json`, a missing source is skipped with a warning. The default config keeps Claude Code's and opencode's global state self-contained under `~/.dev-sandbox/docker-container/agents`, so neither tool needs to be installed on the host and nothing pollutes the host home. Edit this file to add or remove mounts per machine. It is gitignored so it stays local to each machine. (The `dev` / sbx method does not use `mounts`.)

## Usage

```bash
cd /your/project
dev              # sbx sandbox
# or
dev-container    # docker run container
```

`dev` launches a plain shell by default. Pass an agent to launch it instead:

```bash
dev claude       # Claude Code (default model pinned)
dev codex        # Codex
```

`claude` and `shell` share one template image; `codex` uses its own (built from
the codex base image and cached separately, so the first `dev codex` builds it).
Each image also gets its own mixin kits: Claude receives its custom statusline
and dashboard configuration, while Codex receives configuration defaults, the
dashboard plugin, and a native TUI statusline showing its model and reasoning
effort, current directory, tokens used, context-window size/usage, and
5-hour/weekly limits.

To open another shell in the sandbox/container already running for the current directory:

```bash
dev --attach              # or: dev -a
dev-container --attach    # or: dev-container -a
```

`--attach` skips the build and runs a new shell in the existing sandbox/container, matched by the mounted directory. If several are running for the same directory, it lists them and prompts you to choose. Any args after `--attach` run as a command instead of a shell (e.g. `dev --attach ls`).

## Known issues / possible improvements
- Explicit agent-specific ssh keys (not mounting `id_rsa` and `id_rsa.pub` keypair of the host)
- Pre-install tools: scw (I often let AI use this)
