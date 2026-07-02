# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A host-installed tool (`dev`) that builds a Docker image from this repo and drops you into a container with the current directory mounted. The container runs as the host user (via `gosu`) so files created inside don't have root ownership on the host.

Installed to `~/.dev-sandbox/` by cloning this repo and running `install.sh`. The `dev` binary lives at `~/.dev-sandbox/bin/dev` and is added to `PATH` by the user.

## Key files

- `bin/dev` — the CLI entry point. Runs `git pull` on itself, builds the Docker image, reads `mounts`, and starts the container.
- `Dockerfile` — the container image definition. Ubuntu 24.04 with Zsh, Oh My Zsh, Docker CLI, Claude Code, and asdf.
- `entrypoint.sh` — runs inside the container. Creates a user/group matching `HOST_UID`/`HOST_GID`, chowns `/home/ubuntu` dirs to that user, grants passwordless sudo, then `gosu`s into the user.
- `install.sh` — makes `bin/dev` executable and creates a default `mounts` config file at `~/.dev-sandbox/mounts`.
- `uninstall.sh` — removes `~/.dev-sandbox/` with confirmation.
- `mounts` — gitignored, machine-local config file (`source:target[:opts]` per line). Missing sources are skipped with a warning, unless flagged `mkdir`/`touch`/`json` (then created on the host first — as a directory, an empty file, or a file seeded with `{}`).

## How `dev` works end-to-end

1. Self-updates via `git pull` on `~/.dev-sandbox`.
2. Builds the image tagged `dev-sandbox` from `~/.dev-sandbox/Dockerfile`.
3. Reads `~/.dev-sandbox/mounts`, expands `~`, skips missing sources (or creates them on the host when flagged `mkdir`/`touch`/`json`).
4. Runs `docker run -it --rm` with the CWD mounted at `/workspace/<dirname>` inside the container, the container named `dev-<dirname>` (spaces replaced with `_`), `HOST_UID`/`HOST_GID` env vars, and any configured mounts.
5. `entrypoint.sh` creates a matching user inside the container and drops into it via `gosu`.

## Attach mode (`dev --attach` / `dev -a`)

Short-circuits before self-update, build, and mount resolution, then `docker exec`s a new `gosu "$(id -u)"` shell into the container already running for the current directory. The target is identified by its bind mount (`$CWD` → `$WORKDIR`), not by name — the `dev-<dirname>-<random>` name is only a `docker ps` prefilter, since the random suffix means two same-basename directories can each have their own container. If more than one container matches, it lists them and prompts (default = newest). Extra args after `--attach` are run as the command instead of a shell (e.g. `dev --attach ls`).

## Container user model

All tools (Oh My Zsh, asdf, Claude Code) are installed to `/home/ubuntu` during the image build. The entrypoint creates a non-root user matching the host UID/GID with `/home/ubuntu` as their home directory, then chowns its *directories* (not files) to that user so they can write into them. The project directory is mounted separately under `/workspace`, so it's untouched; any configured `mounts` entries that land under `/home/ubuntu` are skipped via `-xdev` since bind mounts are already owned by the host user.

If `HOST_UID=0` (running as root on the host), the entrypoint skips user creation entirely and executes directly.

## Adding tools to the image

Add `RUN` steps to `Dockerfile`. The next `dev` invocation will rebuild the image. Tools that modify `PATH` at runtime (nvm, asdf plugins) should be initialized in `.zshrc` or `.bashrc`, not in `ENTRYPOINT`-level scripts.

## The `mounts` file

Format: one entry per line, `source:target[:opts]`. `opts` is a comma-separated list of `ro` (mount read-only), `mkdir` (create the source as a directory on the host if missing), `touch` (create the source as an empty file on the host if missing, making its parent dirs), and `json` (like `touch`, but seed the file with `{}` — and also re-seed it if it already exists but is empty, since tools like Claude Code choke on an empty file where they expect JSON). `mkdir`/`touch`/`json` mean a missing source is created instead of skipped. Comments (`#`) and blank lines are ignored. Tilde expansion is handled by `bin/dev`. This file is gitignored so it stays local to each machine — `install.sh` creates a default one on first install.

The default config keeps Claude Code's and opencode's global state self-contained under `~/.dev-sandbox`, so neither tool needs to be installed/configured on the host and nothing pollutes the host home:

- `~/.dev-sandbox/agents/claude/config` (`mkdir`) → `~/.claude`, and `~/.dev-sandbox/agents/claude/claude.json` (`json`) → `~/.claude.json`.
- `~/.dev-sandbox/agents/opencode/config` (`mkdir`) → `~/.config/opencode`, and `~/.dev-sandbox/agents/opencode/data` (`mkdir`) → `~/.local/share/opencode`.

This persists each tool's theme, API keys/auth, and global config between runs. The `~/.dev-sandbox/agents/` tree is gitignored so it doesn't interfere with the self-update `git pull`.
