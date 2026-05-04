# Agent Office Dashboard

`visual-media/` is a no-build local dashboard for the file-backed agent-team
workflow. The primary tab is Agent Office, and the secondary tab keeps the media
attachment command builder.

## Run

```bash
./scripts/start-agent-office-dashboard.sh
```

The compatibility launcher still works:

```bash
./scripts/start-visual-media-dashboard.sh
```

Both serve:

```text
http://127.0.0.1:8765/visual-media/
```

Use `--port <port>` to choose a port, or `--print-url [port]` to print the URL
without starting the server.

## Agent Office API

The dashboard server reads the workflow files and normalizes them for the
browser:

- `GET /api/snapshot` reads `.agents/company/agent-profiles.jsonl`,
  `.agents/state/agents.jsonl`, `.agents/state/routes.jsonl`,
  `.agents/events.jsonl`, `.agents/workflow-state.md`, and route reports under
  `.agents/routes/`.
- `POST /api/orchestrator-prompt` accepts `{ "role": "<role>", "message": "<text>" }`,
  validates the role against `.agents/company/agent-profiles.jsonl`, creates the
  next route with `scripts/route-agent.sh --from human-ui`, and queues it to
  `.agents/inbox/orchestrator.md`.

Prompt-created routes always go to Orchestrator. The selected role, status, and
active route are copied into the route instruction as context; direct role
tasking can be added later without changing the source-of-truth model.

## Media Builder

The Media Builder tab exposes the same parameters as `scripts/attach-media.sh`.
It is a command builder for the file-backed functional layer, not a second state
store.

Use Media Builder only when you have a local file that the agent team should
remember as project context. Typical examples are a design screenshot, product
reference image, demo video, audio note, PDF, or validation screenshot. It does
not control agents and it does not change the app being built; it only builds a
safe `scripts/attach-media.sh` command that records where the file is and why it
matters.

Common flow:

1. Put the file somewhere stable, such as `/Users/hay/Desktop/homepage-design.png`.
2. Open Media Builder.
3. Enter the file path, attachment type, scope, related ID, and description.
4. Run the generated command from the agent-team copy.
5. Future agents can find the reference through `.agents/media/manifest.jsonl`
   and `.agents/state/media.jsonl`.

For normal workflow control, use Agent Office and tmux. Use Media Builder only
when you need to attach a file as durable context.

Required command parameters:

- `meeting-id`
- `scope`: `meeting`, `task`, `route`, `validation`, `design`, or `project`
- `related-id`
- `file-path`
- `attachment-type`: `image`, `video`, `screenshot`, `audio`, `document`, or `other`
- `description`

Optional command flags:

- `--copy`
- `--sensitive yes|no|unknown`
- `--review-owner <role>`
- `--attribution <text>`
- `--tags <csv>`
- `--width <pixels>`
- `--height <pixels>`
- `--mime-type <type/subtype>`

The generated command appends records to `.agents/media/manifest.jsonl` and
`.agents/state/media.jsonl`.
