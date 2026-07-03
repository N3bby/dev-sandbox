# dev-sandbox

Starts a Docker container with the current directory mounted, using a shared image definition pulled from this repo.

## Install

```bash
git clone git@github.com:n3bby/dev-sandbox.git ~/.dev-sandbox && bash ~/.dev-sandbox/install.sh
```

Then add to your `.bashrc` or `.zshrc`:

```bash
export PATH="$HOME/.dev-sandbox/bin:$PATH"
```

## Update

The `dev` command pulls the latest changes automatically on each run — no manual update needed.

## Uninstall

```bash
bash ~/.dev-sandbox/uninstall.sh
```

## Configuration

Optional mounts are configured in `~/.dev-sandbox/mounts` — one entry per line:

```
source:target[:opts]
```

```
# comments and blank lines are ignored
/var/run/docker.sock:/var/run/docker.sock
~/.ssh/id_rsa:/home/ubuntu/.ssh/id_rsa:ro
~/.ssh/id_rsa.pub:/home/ubuntu/.ssh/id_rsa.pub:ro
~/.gitconfig:/home/ubuntu/.gitconfig:ro
~/.dev-sandbox/agents/claude/config:/home/ubuntu/.claude:mkdir
~/.dev-sandbox/agents/claude/claude.json:/home/ubuntu/.claude.json:json
~/.dev-sandbox/agents/opencode/config:/home/ubuntu/.config/opencode:mkdir
~/.dev-sandbox/agents/opencode/data:/home/ubuntu/.local/share/opencode:mkdir
~/.dev-sandbox/agents/opencode/state:/home/ubuntu/.local/state/opencode:mkdir
~/.dev-sandbox/agents/opencode/cache:/home/ubuntu/.cache/opencode:mkdir
```

opts` can be:

- `ro` — mount the path read-only.
- `mkdir` — create the source as a directory on the host if it's missing.
- `touch` — create the source as an empty file on the host if it's missing.
- `json` — like `touch`, but seed the file with `{}` (and re-seed it if it already exists but is empty). Use this for tools like Claude Code that fail to start on an empty file where they expect JSON.

Without `mkdir`/`touch`/`json`, a missing source is skipped with a warning. The default config keeps Claude Code's and opencode's global state self-contained under `~/.dev-sandbox`, so neither tool needs to be installed on the host and nothing pollutes the host home. Edit this file to add or remove mounts per machine. It is gitignored so it stays local to each machine.

## Usage

```bash
cd /your/project
dev
```

To open another shell in the container already running for the current directory:

```bash
dev --attach   # or: dev -a
```

`--attach` skips the image build and runs a new shell in the existing container (matched by the mounted directory). If several containers are running for the same directory, it lists them and prompts you to choose.

## Known issues / possible improvements
- Explicit agent-specific ssh keys (not mounting `id_rsa` and `id_rsa.pub` keypair of the host)
