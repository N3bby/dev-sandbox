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
source:target[:ro]
```

```
# comments and blank lines are ignored
/var/run/docker.sock:/var/run/docker.sock
~/.ssh/id_rsa:/root/.ssh/id_rsa:ro
~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:ro
~/.gitconfig:/root/.gitconfig:ro
~/.claude:/root/.claude
~/.claude.json:/root/.claude.json
```

Append `:ro` to mount a path read-only. Missing paths are skipped with a warning. Edit this file to add or remove mounts per machine. It is gitignored so it stays local to each machine.

## Usage

```bash
cd /your/project
dev
```
