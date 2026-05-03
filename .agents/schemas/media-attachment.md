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

Optional fields:

- `mime_type`
- `sensitive`
- `review_owner`
