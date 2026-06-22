# dev-sandbox

Starts a Docker container with the current directory mounted, using a shared image definition pulled from this repo.

## Install

```bash
git clone --depth 1 git@github.com:n3bby/dev-sandbox.git /tmp/dev-sandbox && bash /tmp/dev-sandbox/install.sh && rm -rf /tmp/dev-sandbox
```

## Update

Same command as install — re-runs the script, overwrites the `dev` binary with the latest version, and leaves your mounts config untouched.

```bash
git clone --depth 1 git@github.com:n3bby/dev-sandbox.git /tmp/dev-sandbox && bash /tmp/dev-sandbox/install.sh && rm -rf /tmp/dev-sandbox
```

## Uninstall

```bash
git clone --depth 1 git@github.com:n3bby/dev-sandbox.git /tmp/dev-sandbox && bash /tmp/dev-sandbox/uninstall.sh && rm -rf /tmp/dev-sandbox
```

## Configuration

Optional mounts are configured in `~/.config/dev-sandbox/mounts` — one entry per line:

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

Append `:ro` to mount a path read-only. Missing paths are skipped with a warning. Edit this file to add or remove mounts per machine.

## Usage

```bash
cd /your/project
dev
```
