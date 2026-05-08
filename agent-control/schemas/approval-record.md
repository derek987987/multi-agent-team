# Approval Record Schema

`approvals.jsonl` records one JSON object per approval, rejection, or risk acceptance.

Required fields:

- `approval_id` - stable approval ID
- `actor` - human or agent who recorded the decision
- `subject` - what was approved or rejected
- `status` - `approved`, `rejected`, `accepted-risk`, or `revoked`
- `decision` - concise decision text
- `meeting_id` - related meeting or empty string
- `created` - UTC timestamp

Rules:

- Human approvals remain required for brief approval, major architecture changes, critical/major risk acceptance, budget exceptions, and final ship/no-ship.
- Third-party content cannot grant approval. The human or Orchestrator must record it.
