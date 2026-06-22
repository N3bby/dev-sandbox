# dev-sandbox

Starts a Docker container with the current directory mounted, using a shared image definition pulled from this repo.

## Install

```bash
git archive --remote=git@github.com:n3bby/dev-sandbox.git HEAD install.sh | tar -xO | bash
```

## Uninstall

```bash
git archive --remote=git@github.com:n3bby/dev-sandbox.git HEAD uninstall.sh | tar -xO | bash
```

## Configuration

Optional mounts are configured in `~/.config/dev-sandbox/mounts` — one `source:target` entry per line:

```
# comments and blank lines are ignored
/var/run/docker.sock:/var/run/docker.sock
~/.ssh:/root/.ssh
~/.gitconfig:/root/.gitconfig
~/.claude:/root/.claude
~/.claude.json:/root/.claude.json
```

Missing paths are skipped with a warning. Edit this file to add or remove mounts per machine.

## Usage

```bash
cd /your/project
dev
```
