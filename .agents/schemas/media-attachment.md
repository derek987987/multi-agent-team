# Media Attachment Schema

`media/manifest.jsonl` records one JSON object per attachment.

Required fields:

- `attachment_id` - stable generated ID
- `meeting_id` - related meeting or empty string
- `scope` - `meeting`, `task`, `route`, `validation`, `design`, or `project`
- `related_id` - route/task/meeting/project ID
- `path` - local file path
- `attachment_type` - `image`, `video`, `screenshot`, `audio`, `document`, or `other`
- `description` - why this media exists
- `created` - UTC timestamp
- `file_size` - source file size in bytes
- `sha256` - source file SHA-256 digest when the host can compute it
- `mime_type` - detected or explicitly supplied MIME type

Optional fields:

- `stored_path` - copied path under `.agents/media/files/` when `--copy` is used
- `sensitive` - `yes`, `no`, or `unknown`
- `review_owner` - role responsible for review when sensitivity or usage risk exists
- `attribution` - source, license, or origin note
- `tags` - comma-separated filter tags
- `width` - image or video width in pixels
- `height` - image or video height in pixels

Use `scripts/attach-media.sh` to write both `.agents/media/manifest.jsonl` and
`.agents/state/media.jsonl`; use the Media Builder tab in `visual-media/` for
the visible option builder.
