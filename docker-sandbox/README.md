# docker-sandbox/ — Docker Sandboxes (`sbx`) rewrite

A work-in-progress port of the container-based `dev` tool onto
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). Each sandbox is an
isolated **microVM** (own kernel, filesystem, private Docker engine, deny-by-default
network) rather than a `--rm` container sharing the host daemon.

This exists alongside the original (repo-root `bin/dev`, `Dockerfile`,
`entrypoint.sh`) so the two can be compared before anything is switched over.

## Layout

| Path | Role | Replaces |
|---|---|---|
| `template/Dockerfile` | Template image: extras layered on Docker's `claude-code` base template | repo-root `Dockerfile` (minus all UID/GID + chown logic) |
| `kit/spec.yaml` | Kit: network allowlist, entrypoint, injected files, agent context | `mounts`, `entrypoint.sh`, the claude-bypass hack |
| `kit/files/` | Non-secret prefs injected at creation (`home/` → `/home/agent/`) | the state half of `mounts` (theme, dotfiles) — now **synced** |
| `bin/dev` | Thin wrapper: install sbx, sync kit, run, attach | repo-root `bin/dev` (~200 lines → ~130) |

## Usage

```sh
dev                 # run Claude in an isolated sandbox for the current dir
dev ~/shared:ro     # + mount an extra read-only workspace
dev --attach        # open a shell in this dir's running sandbox
dev --attach ls     # run a one-off command in it
dev --build         # (re)build the template now, without starting a sandbox
```

`dev` installs the `sbx` CLI automatically on first run (Homebrew on macOS,
Docker's apt repo on Debian/Ubuntu). After install, run `sbx login` **once per
machine** to authenticate.

**The template builds itself.** Every `dev` run does a `docker build` of the
template first — cheap, because Docker caches the layers. It only pays the slow
`docker save` + `sbx template load` step when the built image actually changed
(or isn't loaded in sbx yet), tracked by a machine-local image-ID stamp under
`$XDG_STATE_HOME/dev-sandbox/`. So you never have to remember to build; `dev
--build` is just the explicit "build and stop" form.

## How the pieces map to the old design

- **Built on Docker's official base template.** `template/Dockerfile` starts
  `FROM docker/sandbox-templates:claude-code-minimal`, which already ships the
  `agent` user (UID 1000) + sudo, the injected proxy env, git, the Docker CLI,
  and Claude Code. We use the `-minimal` variant (no bundled Node/Python/Go/Java)
  because we bring our own pinned python/node via asdf, and layer on zsh/omz +
  prompt + the asdf toolchain — so all the old user-rename / locale /
  Docker-CLI-apt / claude-install boilerplate is gone.
- **No `entrypoint.sh`, no UID/GID reconciliation, no runtime chown.** sbx runs
  every sandbox as a fixed non-root `agent` user (UID 1000) and mounts the
  workspace directly, so host files never come back root-owned.
- **No self-update of the whole tool** — `sbx` upgrades via brew/apt. `dev` only
  `git pull`s this repo to keep the local **kit** current (the sync channel).
- **Attach is simpler**: sandbox names are deterministic (`dev-<dir>-<hash>`), so
  `dev --attach` recomputes the name and `sbx exec`s in — no container matching.

## Config sync across machines

Three layers, synced very differently on purpose:

1. **Environment definition** (template + kit): shared via git/registry. Either
   let `dev` `git pull` this repo (default), or set `DEV_KIT` to a pinned ref:
   ```sh
   export DEV_KIT='git+https://github.com/<org>/dev-sandbox.git#ref=v1.0&dir=docker-sandbox/kit'
   ```
2. **Non-secret prefs** (theme, dotfiles): drop them in `kit/files/home/` — they
   travel with the kit and become synced-by-default (unlike the old gitignored,
   machine-local tool state).
3. **Secrets/auth**: never in git. One-time-per-machine `sbx login` /
   `sbx secret set`; the host-side proxy injects them without them entering the VM.

## Open items to verify on a real sbx host

These couldn't be confirmed from the docs alone and are marked `TODO(verify)` in
the files:

- **Kit schema version.** `kit/spec.yaml` uses the **v0.32.0+** field names
  (`kind: sandbox`, `sandbox:`, `agentContext:`) — requires `sbx >= 0.32.0`.
  Older sbx used `kind: agent` / `agent:` / `memory:`; check with `sbx version`.
- **Local vs. registry image.** *Resolved.* sbx runs in its own microVM runtime
  that can't see the host Docker image store, so a locally-built image is
  exported (`docker image save`) and imported with `sbx template load` — this is
  what `dev --build` does. For multi-machine use, push to a registry instead and
  point `sandbox.image` at that ref.
- **Network allowlist.** `kit/spec.yaml`'s `allowedDomains` is a starter list —
  tighten or extend once you see what your workflows actually reach.

## Requirements

Hardware virtualization is mandatory: macOS Apple Silicon (Sonoma 14+), Windows 11
(Hyper-V), or Linux with KVM (Ubuntu 24.04+). Intel Macs are not supported.
