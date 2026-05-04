# Media Attachments

Media attachments are metadata records for images, videos, screenshots, audio,
and other local reference files used by meetings, tasks, routes, validation, or design.

## Files

- `manifest.jsonl` - append-only media attachment ledger.
- `files/` - optional copied media storage created by `scripts/attach-media.sh --copy`.

## Rules

- Store local file paths and purpose first. Visual previews come later.
- Do not attach secrets, credentials, private keys, or unrelated personal files.
- Security review is required when media may contain sensitive personal, financial, medical, or credential data.

## When To Use Media Builder

Use the Media Builder tab when you have a local file that should become durable
context for the agent team. Examples include a UI screenshot, design reference,
demo video, audio note, PDF, or validation screenshot.

Media Builder does not run agents or change the target app. It only builds the
matching `scripts/attach-media.sh` command so the file is recorded in
`.agents/media/manifest.jsonl` and `.agents/state/media.jsonl`.

For normal agent control, use the tmux Orchestrator window or the Agent Office
prompt box. Use Media Builder only when there is a file to attach.

## Attach Command

```bash
./scripts/attach-media.sh M001 meeting M001 /path/to/reference.png screenshot "Reference UI" \
  --copy \
  --sensitive no \
  --review-owner security \
  --attribution "Product discussion reference" \
  --tags "design,visual,reference" \
  --width 1200 \
  --height 800
```

Required options:

- `meeting-id`
- `scope`: `meeting`, `task`, `route`, `validation`, `design`, or `project`
- `related-id`
- `file-path`
- `attachment-type`: `image`, `video`, `screenshot`, `audio`, `document`, or `other`
- `description`

Optional flags:

- `--copy`
- `--sensitive yes|no|unknown`
- `--review-owner <role>`
- `--attribution <text>`
- `--tags <csv>`
- `--width <pixels>`
- `--height <pixels>`
- `--mime-type <type/subtype>`

For the visible command builder, run `scripts/start-agent-office-dashboard.sh`
and open the Media Builder tab. `scripts/start-visual-media-dashboard.sh`
remains as a compatibility launcher.
