# docker-sandbox/ — Docker Sandboxes (`sbx`) rewrite

A port of the container-based `dev` tool onto
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). Each sandbox is an
isolated **microVM** (own kernel, filesystem, private Docker engine, deny-by-default
network) rather than a `--rm` container sharing the host daemon.

This exists alongside the original (repo-root `bin/dev`, `Dockerfile`,
`entrypoint.sh`) so the two can be compared before anything is switched over.

## Layout

| Path | Role | Replaces |
|---|---|---|
| `kit/spec.yaml` | A **mixin** kit: network allowlist, install commands, env, agent context | `Dockerfile`, `mounts`, `entrypoint.sh`, the claude-bypass hack |
| `kit/files/` | Non-secret prefs injected at creation (`home/` → `/home/agent/`) | the state half of `mounts` (theme, dotfiles) — now **synced** |
| `bin/dev` | Thin wrapper: install sbx, sync kit, run, attach | repo-root `bin/dev` |

**There is no custom image.** The kit is a `kind: mixin` layered onto the stock
`claude` agent, which already runs on Docker's `claude-code` base image — so the
`agent` user, proxy env, git, the Docker CLI **+ a working private Docker
daemon**, and Node/Python/Go/Java all come for free. We just layer zsh/omz +
prompt and asdf on top via the kit's `commands.install`. No Dockerfile, no
`docker build`, no `sbx template load`.

## Usage

```sh
dev                 # run Claude in an isolated sandbox for the current dir
dev ~/shared:ro     # + mount an extra read-only workspace
dev --attach        # open a shell in this dir's running sandbox
dev --attach ls     # run a one-off command in it
```

`dev` installs the `sbx` CLI automatically on first run (Homebrew on macOS,
Docker's apt repo/RPM on Linux). After install, run `sbx login` **once per
machine** to authenticate.

The kit's `commands.install` (zsh, oh-my-zsh, asdf, terraform plugin) run
**once per sandbox, at creation**, on top of the base image. Creating a fresh
sandbox is therefore a little slower than attaching to an existing one, but the
sandbox persists and is reused.

## How the pieces map to the old design

- **No custom image / no build step.** A mixin kit installs our extras onto the
  stock `claude` agent's default image at creation time. That image already
  satisfies the whole template contract (agent user at UID 1000 + sudo, injected
  proxy env, git, Docker CLI + daemon, language runtimes), so all the old
  user-rename / locale / Docker-CLI-apt / claude-install boilerplate is gone.
- **No `entrypoint.sh`, no UID/GID reconciliation, no runtime chown.** sbx runs
  every sandbox as a fixed non-root `agent` user (UID 1000) and mounts the
  workspace directly, so host files never come back root-owned.
- **No self-update of the whole tool** — `sbx` upgrades via brew/apt/RPM. `dev`
  only `git pull`s this repo to keep the local **kit** current (the sync channel).
- **Attach is simpler**: sandbox names are deterministic (`dev-<dir>-<hash>`), so
  `dev --attach` recomputes the name and `sbx exec`s in — no container matching.
- **Permission prompts skipped**: `dev` passes `-- --dangerously-skip-permissions`
  to Claude — the sandbox itself is the isolation boundary.

## Config sync across machines

Three layers, synced very differently on purpose:

1. **Environment definition** (the kit): shared via git. Either let `dev`
   `git pull` this repo (default), or set `DEV_KIT` to a pinned ref:
   ```sh
   export DEV_KIT='git+https://github.com/<org>/dev-sandbox.git#ref=v1.0&dir=docker-sandbox/kit'
   ```
2. **Non-secret prefs** (theme, dotfiles): drop them in `kit/files/home/` — they
   travel with the kit and become synced-by-default (unlike the old gitignored,
   machine-local tool state).
3. **Secrets/auth**: never in git. One-time-per-machine `sbx login` /
   `sbx secret set`; the host-side proxy injects them without them entering the VM.

## Requirements

Hardware virtualization is mandatory: macOS Apple Silicon (Sonoma 14+), Windows 11
(Hyper-V), or Linux with KVM (Ubuntu 24.04+). Intel Macs are not supported.
Requires `sbx >= 0.32.0` for the current kit schema (`kind: mixin`, `commands`,
`agentContext`).
