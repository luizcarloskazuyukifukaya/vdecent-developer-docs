# App Email API Deep Dive

Technical reference for the Notification Service app-mail API used by a V-Decent app's approved email identity. For the end-to-end enablement and development approach, see the [App Email Developer Guide](app-email-developer-guide.md).

## Authentication and environment

| Variable | Purpose |
| --- | --- |
| `MAIL_API_URL` | Notification Service base URL for the environment. |
| `MAIL_API_TOKEN` | App identity API token. Backend only. |
| `MAIL_FROM` | Approved app address. Informational; the server resolves the identity. |
| `MAIL_REPLY_TO` | Approved reply address. Informational; the server resolves the identity. |
| `MAIL_INBOUND_MODE` | Inbound mode provisioned for the app (`webhook` in the App Manager flow). |
| `MAIL_INBOUND_WEBHOOK_SECRET` | HMAC secret for inbound webhook verification. Backend only. |

Environments:

| Environment | `MAIL_API_URL` |
| --- | --- |
| Development/PoC | `https://notification-api-dev.v-decent.org` |
| Production | `https://notification-api.v-decent.org` |

Send `Authorization: Bearer <MAIL_API_TOKEN>` on every call. The token is scoped to exactly one approved identity. A token for one identity cannot read or send as another identity.

## Send: `POST /api/v1/app-mail/messages`

Headers:

```
Authorization: Bearer <MAIL_API_TOKEN>
Idempotency-Key: <1-200 chars, stable per logical message>
Content-Type: application/json
```

Body schema (`extra="forbid"`; unknown fields are rejected):

| Field | Type | Rules |
| --- | --- | --- |
| `to` | string | One valid email address. One recipient per request. |
| `subject` | string | 1-200 characters, no CR/LF. |
| `text` | string or null | Plain-text body, up to 262,144 UTF-8 bytes. |
| `html` | string or null | HTML body, up to 262,144 UTF-8 bytes. |
| `attachments` | array | Up to 3 items, total decoded size <= 5 MB. |

At least one of `text` or `html` is required. Send both for best client compatibility. `From` and `Reply-To` are resolved by the Notification Service from the identity; the request cannot override them.

Attachment item:

| Field | Rules |
| --- | --- |
| `filename` | 1-255 chars, no CR/LF. |
| `contentType` | `application/pdf`, `image/png`, `image/jpeg`, `text/csv`, or `text/plain`. Parameters such as `; charset=UTF-8` are stripped. |
| `contentBase64` | Standard Base64; decoded total across attachments must be <= 5 MB. |

There is no antivirus/content scanning at launch.

Example:

```bash
curl -X POST "$MAIL_API_URL/api/v1/app-mail/messages" \
  -H "Authorization: Bearer $MAIL_API_TOKEN" \
  -H "Idempotency-Key: order-1234-shipped" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "customer@example.com",
    "subject": "Your order shipped",
    "text": "Your order shipped.",
    "html": "<p>Your order shipped.</p>",
    "attachments": [
      {
        "filename": "invoice.pdf",
        "contentType": "application/pdf",
        "contentBase64": "JVBERi0xLjQK..."
      }
    ]
  }'
```

Success response: HTTP `202 Accepted`.

```json
{
  "id": "7d4b9d7c-7a0a-4f31-b8a5-3f0f1e3a1c11",
  "status": "pending",
  "attempts": 0,
  "last_error": null
}
```

`202` means the message is durably queued, not delivered.

## Status: `GET /api/v1/app-mail/messages/{id}`

Headers: `Authorization: Bearer <MAIL_API_TOKEN>`.

Returns the same receipt shape for a message owned by the token's identity. Unknown IDs and IDs belonging to another identity return `404`.

| Status | Meaning |
| --- | --- |
| `pending` | Queued or awaiting retry. |
| `accepted` | Delivery provider accepted the message. |
| `failed` | Permanent rejection or retry attempts exhausted. |
| `muted` | Operator muted the email channel; delivery skipped. |

`last_error` contains an exception class/type, not provider content. Transient failures retry after 30, 60, 120, and 240 seconds, up to five attempts. Permanent rejections fail immediately. There is no replay endpoint.

## Idempotency

- Keys are unique per identity.
- Reusing a key with identical content returns the original receipt.
- Reusing a key with different content returns `409`.
- Generate one key per logical message and reuse it across retries.
- Do not key by timestamp or random per attempt; that defeats deduplication.
- Safe pattern: `order-<id>-shipped`, `invoice-<id>-created`, `password-reset-<user>-<request-id>`.

## Quotas and rate limits

Default per identity:

- 60 messages per minute.
- 1,000 messages per day.

`429` indicates the quota is exhausted. Honor the `Retry-After` header. Quotas are per identity and are counted when a message is accepted into the outbox.

## Error responses

| Status | Cause |
| --- | --- |
| `401` | Missing, invalid, or wrong-environment token. |
| `403` | Identity is not active (suspended or not yet verified). |
| `409` | Idempotency key reused with different content. |
| `413` | Attachment total exceeds 5 MB. |
| `422` | Invalid recipient/subject/body, unknown field, invalid Base64, unsupported attachment type, or more than 3 attachments. |
| `429` | Per-minute or daily quota exhausted; retry after the header value. |

Retry policy in the app:

- Retry connection failures, timeouts, `429`, and `5xx` with the same idempotency key.
- Do not retry `400`/`401`/`403`/`409`/`413`/`422` unchanged.
- `409` means the key was reused with different content; use a new key for a new logical message.

## Retention

Message bodies and attachments are retained for the configured app-mail retention window (default 7 days). After that, terminal messages are redacted and attachments deleted. Receipts/status rows remain. Do not use the status endpoint as a long-term message archive.

## Inbound webhook contract

When inbound mode is `webhook`, the per-app Email Worker POSTs to:

```
https://<app-fqdn>/webhooks/vdecent-mail
```

Headers:

```
Content-Type: application/json
X-VDecent-Signature: sha256=<hex HMAC-SHA256 of the exact request body>
X-VDecent-Delivery-Id: <deliveryId>
```

Payload:

```json
{
  "deliveryId": "<Message-ID or UUID>",
  "to": "contact-<shortname>@<app-domain>",
  "from": "sender@example.com",
  "subject": "Re: Invoice",
  "text": "Plain text body",
  "html": "<p>HTML body</p>",
  "headers": {
    "message-id": "<...>",
    "date": "<...>",
    "from": "<...>",
    "to": "<...>",
    "subject": "<...>"
  },
  "receivedAt": "2026-11-26T21:57:47.000Z"
}
```

Verification rules:

- HMAC the raw body bytes exactly as received, before JSON parsing.
- Use constant-time comparison.
- Reject missing/invalid signatures with `401`.
- Deduplicate by `deliveryId`; the same message may be retried.
- Return `2xx` quickly and process asynchronously.
- Attachments are not forwarded in webhook mode at launch.

Python verification:

```python
import hashlib
import hmac
import os

from fastapi import HTTPException, Request


async def verify_vdecent_signature(request: Request) -> bytes:
    raw = await request.body()
    expected = "sha256=" + hmac.new(
        os.environ["MAIL_INBOUND_WEBHOOK_SECRET"].encode(),
        raw,
        hashlib.sha256,
    ).hexdigest()
    received = request.headers.get("X-VDecent-Signature", "")
    if not hmac.compare_digest(received, expected):
        raise HTTPException(401, "Invalid webhook signature")
    return raw
```

Node.js verification:

```javascript
import crypto from "node:crypto";

export function verifyVDecentSignature(rawBody, signature) {
  const expected = "sha256=" + crypto
    .createHmac("sha256", process.env.MAIL_INBOUND_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  const a = Buffer.from(expected);
  const b = Buffer.from(signature || "");
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
```

Fallback behavior: if the webhook returns non-2xx, times out, or the Worker cannot deliver, the Email Worker forwards the message to the app's owner inbox. A successful webhook delivery does not send a copy to the owner inbox.

## Minimal client wrappers

Python:

```python
import os
import httpx

class AppMailClient:
    def __init__(self):
        self.base = os.environ["MAIL_API_URL"].rstrip("/")
        self.token = os.environ["MAIL_API_TOKEN"]

    def submit(self, *, to, subject, text=None, html=None, key, attachments=None):
        response = httpx.post(
            f"{self.base}/api/v1/app-mail/messages",
            headers={
                "Authorization": f"Bearer {self.token}",
                "Idempotency-Key": key,
            },
            json={
                "to": to,
                "subject": subject,
                "text": text,
                "html": html,
                "attachments": attachments or [],
            },
            timeout=10,
        )
        response.raise_for_status()
        return response.json()

    def status(self, message_id):
        response = httpx.get(
            f"{self.base}/api/v1/app-mail/messages/{message_id}",
            headers={"Authorization": f"Bearer {self.token}"},
            timeout=10,
        )
        response.raise_for_status()
        return response.json()
```

Node.js:

```javascript
export class AppMailClient {
  constructor(env = process.env) {
    this.base = env.MAIL_API_URL.replace(/\/$/, "");
    this.token = env.MAIL_API_TOKEN;
  }

  async submit({ to, subject, text, html, key, attachments = [] }) {
    const response = await fetch(`${this.base}/api/v1/app-mail/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Idempotency-Key": key,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ to, subject, text, html, attachments }),
    });
    if (!response.ok) throw new Error(`App mail HTTP ${response.status}`);
    return response.json();
  }

  async status(id) {
    const response = await fetch(`${this.base}/api/v1/app-mail/messages/${id}`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    if (!response.ok) throw new Error(`App mail HTTP ${response.status}`);
    return response.json();
  }
}
```
