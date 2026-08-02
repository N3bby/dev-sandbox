# sbx mixin kits

Mixin kits for Docker Desktop AI sandboxes (`sbx`), stacked onto the built-in
`claude` agent kit. See https://docs.docker.com/ai/sandboxes/customize/kits/.

- `statusline/` — ships `claude-template/statusline-command.sh` and merges
  `statusLine` into `~/.claude/settings.json` on every start.
- `claude-dashboard/` — registers the private
  `github.com/N3bby/claude-dashboard` marketplace over HTTPS and installs/
  configures the `claude-dashboard` plugin.

## Usage

```console
$ sbx run claude --kit ./sbx-kits/statusline/ --kit ./sbx-kits/claude-dashboard/
```

To add to an already-running sandbox:

```console
$ sbx kit add <sandbox-name> ./sbx-kits/statusline/
$ sbx kit add <sandbox-name> ./sbx-kits/claude-dashboard/
```

Validate before use:

```console
$ sbx kit validate ./sbx-kits/statusline/
$ sbx kit validate ./sbx-kits/claude-dashboard/
```

## Known caveats (unverified — needs a real `sbx run` to confirm)

- **`claude-dashboard` install order**: `commands.install` for a mixin isn't
  documented to run strictly after the base `claude` kit's own install step,
  so the marketplace-add command retries for up to 30s waiting for the
  `claude` binary to appear on `PATH` before giving up.
- **`serverUrl: http://100.127.103.89:4317`**: this looks like a Tailscale
  address. Verified reachable *from this current sandbox* (got a real
  response from the claude-dashboard app itself, routed through this
  sandbox's forward proxy) — so Tailscale connectivity does reach the
  proxy at the host/network level here. Not yet verified: whether a
  *freshly created* sandbox (via `sbx run claude --kit ...`) has the same
  permissive network policy, since this sandbox may already have a
  broader allow rule (e.g. `sbx policy allow network "**"`) than a new
  one would start with. The `claude-dashboard` mixin's `allowedDomains`
  now includes `100.127.103.89/32` (single-host CIDR) so a fresh sandbox
  under deny-all can reach the dashboard. Docker's network engine matches
  CIDR ranges (IPv4/IPv6) as well as hostnames, but the kit-reference page
  only *explicitly* documents wildcards for `allowedDomains`, so IP/CIDR
  acceptance in a kit is inferred from the shared rule engine rather than
  spelled out — worth confirming `sbx policy log` shows the connection as
  allowed once you run it for real.
- **`settings.json` reseeding**: both mixins reassert their config in
  `commands.startup` (jq merge) because the sandbox rewrites
  `~/.claude/settings.json` after kit files are applied — this is
  documented behavior, not a guess, but the exact ordering relative to
  `commands.install` wasn't confirmed.
