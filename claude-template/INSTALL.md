# Claude Code statusline template

This is the custom statusline used in this environment: model + effort level,
current directory, a context-window usage bar, and (if available) 5-hour /
7-day quota usage — with graceful multi-line wrapping on narrow terminals.

## Files

- `statusline-command.sh` — the script Claude Code invokes to render the statusline.

## Requirements

- `bash`
- `jq`
- standard `awk`, `date`, `tput` (present on virtually all Linux/macOS systems)

## Install on a new system

1. Copy the script into place and make it executable:

   ```bash
   mkdir -p ~/.claude
   cp statusline-command.sh ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Add the `statusLine` entry to `~/.claude/settings.json`.

     ```json
     {
       "...": "...your existing settings...",
       "statusLine": {
         "type": "command",
         "command": "bash /home/ubuntu/.claude/statusline-command.sh"
       }
     }
     ```

   Note the `command` path is absolute. Update it if your home directory
   isn't `/home/ubuntu` (e.g. `bash $HOME/.claude/statusline-command.sh`
   also works).

3. Restart Claude Code (or start a new session) — the statusline should
   appear at the bottom of the terminal automatically.

## Verifying it works

You can test the script manually by feeding it a sample JSON payload:

```bash
echo '{
  "model": {"display_name": "Claude"},
  "effort": {"level": "high"},
  "workspace": {"current_dir": "/workspace/example"},
  "context_window": {"total_input_tokens": 12000, "context_window_size": 200000, "used_percentage": 6},
  "rate_limits": {}
}' | bash ~/.claude/statusline-command.sh
```

You should see colored output like:

```
Claude (high) example ▓░░░░░░░░░ 12k/200k (6%)
```
