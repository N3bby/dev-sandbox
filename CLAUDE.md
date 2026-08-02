# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A host-installed toolkit that drops you into a throwaway dev environment with the current directory mounted, using an image/template definition pulled from this repo. It ships **two** commands, each backed by its own directory:

- **`dev`** (docker-sandbox method) — runs each session inside a Docker *Sandbox* (`sbx`). Everything it uses lives under `docker-sandbox/`.
- **`dev-container`** (docker-container method) — runs a plain `docker run` container as the host user (via `gosu`) so files created inside don't have root ownership on the host. Everything it uses lives under `docker-container/`.

Installed to `~/.dev-sandbox/` by cloning this repo and running `install.sh`. Both binaries live under `~/.dev-sandbox/bin/` and that dir is added to `PATH` by the user.

## Layout

```
bin/dev                      # docker-sandbox entry point (sbx)
bin/dev-container            # docker-container entry point (docker run)
docker-sandbox/              # everything the `dev` command uses
  template/                  #   sbx template image definition
    Dockerfile               #   base image is an ARG (BASE_IMAGE), set per agent variant
    dev-sandbox-sbx-*.tar    #   built template per variant, gitignored (docker image save)
  kits/                      #   sbx mixin kits (--kit), selected per image variant
    claude-statusline/
    claude-dashboard/
    codex-config/            #   Codex CLI defaults layered onto the codex variant
    codex-statusline/        #   Native Codex TUI footer configuration
docker-container/            # everything the `dev-container` command uses
  Dockerfile                 #   container image definition
  entrypoint.sh              #   runs inside the container as the host user
  mounts                     #   gitignored, machine-local mount config
  agents/                    #   gitignored agent state (claude/opencode), persisted between runs
install.sh                   # shared: chmods both binaries, seeds the default mounts config
uninstall.sh                 # shared: removes ~/.dev-sandbox with confirmation
```

Shared files (`install.sh`, `uninstall.sh`, `README.md`, this file) stay at the repo root. Both entry scripts stay under `bin/` because that's the directory the user puts on `PATH`; only each method's supporting assets live under its own dir. Each script resolves `REPO_DIR` as the parent of `bin/` and reaches into the appropriate method dir from there.

## The `dev` command (docker-sandbox / sbx)

`bin/dev`. End-to-end:

1. Self-updates via `git pull` on `~/.dev-sandbox`; re-execs (carrying `DEV_SBX_REBUILD=1`) if HEAD moved.
2. Builds the template image *for the requested agent's variant* from `docker-sandbox/template/` and `docker image save`s it to `docker-sandbox/template/dev-sandbox-sbx-<variant>.tar`, then imports it with `sbx template load`. The one `Dockerfile` is parameterized by a `BASE_IMAGE` build-arg: the `claude-code` variant (used by the `shell` and `claude` agents) builds from the claude-code base image, the `codex` variant (used by `codex`) from the codex base image. Each variant is a separate tag (`dev-sandbox-sbx:<variant>`) with its own tar, built/cached independently, so only the variant needed for this run is built. Rebuilds when the pull brought a change, that variant's tar is missing, or that variant isn't in `sbx` yet.
3. Starts a fresh sandbox for the current directory with a unique name (`dev-<slug>-<pid>-<rand>`), so repeated runs in one directory yield independent sandboxes. Mixin kits from `docker-sandbox/kits/` are selected per image variant and layered on via `--kit`: `shell` and `claude` get the Claude Code statusline and dashboard kits, while `codex` gets its configuration and native TUI statusline kits. The default agent is a plain `shell`; running `dev claude` launches the Claude Code agent, which additionally pins the model to a default; `dev codex` launches the Codex agent. On exit (or Ctrl-C) the sandbox is stopped and removed via a trap.

`dev -a` / `--attach` short-circuits all of the above and `sbx exec`s a zsh shell into a running sandbox for the current directory, matching on the recorded workspace path (both logical and symlink-resolved). Prompts when several match. Extra args after `--attach` run as the command instead of a shell.

## The `dev-container` command (docker-container / docker run)

`bin/dev-container`. End-to-end:

1. Self-updates via `git pull` on `~/.dev-sandbox`; re-execs if HEAD moved.
2. Builds the image tagged `dev-sandbox` from `docker-container/` (build context), passing `HOST_UID`/`HOST_GID` build args so `/home/ubuntu` ownership is baked in.
3. Reads `docker-container/mounts`, expands `~`, skips missing sources (or creates them on the host when flagged `mkdir`/`touch`/`json`).
4. Runs `docker run -it --rm` with the CWD mounted at `/workspace/<dirname>`, the container named `dev-<dirname>-<rand>`, `HOST_UID`/`HOST_GID`/`IS_SANDBOX` env vars, and any configured mounts. When the command is `claude`, injects `--dangerously-skip-permissions`.
5. `docker-container/entrypoint.sh` creates a user/group matching `HOST_UID`/`HOST_GID`, chowns `/home/ubuntu` *directories* (not files) to that user, grants passwordless sudo, then `gosu`s into the user.

`dev-container -a` / `--attach` `docker exec`s a new `gosu` shell into a container already running for this directory, identified by its `$CWD` → `$WORKDIR` bind mount (the name prefix is only a prefilter). Prompts when several match. Extra args after `--attach` run as the command instead of a shell.

### Container user model

All tools (Oh My Zsh, asdf, Claude Code) are installed to `/home/ubuntu` during the image build. The entrypoint creates a non-root user matching the host UID/GID with `/home/ubuntu` as their home, then chowns its *directories* (not files) so they can write into them. The project directory is mounted separately under `/workspace`, so it's untouched; any `mounts` entries that land under `/home/ubuntu` are skipped via `-xdev` since bind mounts are already owned by the host user.

## Adding tools to the images

Add `RUN` steps to the relevant Dockerfile (`docker-container/Dockerfile` or `docker-sandbox/template/Dockerfile`). The next invocation of the corresponding command rebuilds. Tools that modify `PATH` at runtime (nvm, asdf plugins) should be initialized in `.zshrc`/`.bashrc`, not in `ENTRYPOINT`-level scripts.

## The `mounts` file (docker-container only)

`docker-container/mounts`. Format: one entry per line, `source:target[:opts]`. `opts` is a comma-separated list of `ro` (mount read-only), `mkdir` (create the source as a directory on the host if missing), `touch` (create the source as an empty file on the host if missing, making its parent dirs), and `json` (like `touch`, but seed the file with `{}` — and also re-seed it if it exists but is empty, since tools like Claude Code choke on an empty file where they expect JSON). `mkdir`/`touch`/`json` mean a missing source is created instead of skipped. Comments (`#`) and blank lines are ignored. Tilde expansion is handled by `bin/dev-container`. This file is gitignored so it stays local to each machine — `install.sh` creates a default one on first install.

The default config keeps Claude Code's and opencode's global state self-contained under `~/.dev-sandbox/docker-container/agents`, so neither tool needs to be installed/configured on the host and nothing pollutes the host home:

- `.../agents/claude/config` (`mkdir`) → `~/.claude`, and `.../agents/claude/claude.json` (`json`) → `~/.claude.json`.
- `.../agents/opencode/config` (`mkdir`) → `~/.config/opencode`, `.../agents/opencode/data` (`mkdir`) → `~/.local/share/opencode`, `.../agents/opencode/state` (`mkdir`) → `~/.local/state/opencode`, and `.../agents/opencode/cache` (`mkdir`) → `~/.cache/opencode`. opencode spreads its files across all four XDG dirs: config holds `opencode.json`, data holds `opencode.db`/auth, **state holds `kv.json` — the TUI-selected theme and other prefs** (so without it a changed theme resets every run), and cache holds `models.json`/downloaded bins (persisted only to avoid re-downloading).

This persists each tool's theme, API keys/auth, and global config between runs. The `docker-container/agents/` tree is gitignored so it doesn't interfere with the self-update `git pull`. It is only mounted for the docker-container method — the `dev` (sbx) command does not use it.
