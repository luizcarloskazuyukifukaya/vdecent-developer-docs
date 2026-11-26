# App Email Developer Guide

This guide is for developers building apps on V-Decent. It explains how to enable email for an app, how the app sends mail as its approved address, and how to receive inbound mail. The low-level Notification Service API contract is in the separate [App Email API deep dive](app-email-api-deep-dive.md).

## What the app gets

- One approved address on the app domain, normally `contact-<shortname>@<app-domain>`.
- Outbound email through the V-Decent Notification Service. The app never holds SMTP provider credentials.
- Replies routed to the owner inbox, and optionally a signed webhook into the app.
- Runtime environment variables injected by App Manager when email is approved.
- Monthly email add-on fee, recorded separately from the app hosting fee.

The app cannot send as `notifications@v-decent.org`, `contact@v-decent.org`, or any other app's address.

## 1. Enable email from App Manager

1. Open the app in App Manager and go to its **App email** card.
2. Open **Configure email** (`/applications/{id}/email`).
3. Accept the separate monthly email fee notice.
4. Enter:
   - the local part (`contact-<shortname>` is the default),
   - the owner inbox that receives replies,
   - the sender display name.
5. Submit for approval.
6. A V-Decent operator verifies the owner inbox in Cloudflare and approves the request, setting the monthly amount.
7. App Manager provisions the Notification Service identity, Cloudflare routing and Worker, injects the `MAIL_*` environment variables, and redeploys the app.

Email is active only after approval and a successful redeploy. The app address, owner inbox, and monthly amount are visible on the app email card.

If the app address or owner inbox is changed later, the address change goes through operator approval again; owner-inbox/display-name changes apply without a new address request.

## 2. Read the injected environment

After redeploy, the app receives:

```dotenv
MAIL_API_URL=https://notification-api-dev.v-decent.org
MAIL_API_TOKEN=...
MAIL_FROM=contact-<shortname>@<app-domain>
MAIL_REPLY_TO=contact-<shortname>@<app-domain>
MAIL_INBOUND_MODE=webhook
MAIL_INBOUND_WEBHOOK_SECRET=...
```

Rules:

- Use `MAIL_API_URL` from the environment; Development/PoC and Production use different hosts.
- Keep `MAIL_API_TOKEN` and `MAIL_INBOUND_WEBHOOK_SECRET` backend-only. Never expose them in browser bundles, mobile apps, logs, or build arguments.
- Do not hard-code or override `From`/`Reply-To`. The Notification Service resolves them from the approved identity.
- The app address is supplied by App Manager. Do not invent one.

## 3. Send email from the app

Make a backend request:

```
POST {MAIL_API_URL}/api/v1/app-mail/messages
Authorization: Bearer {MAIL_API_TOKEN}
Idempotency-Key: {unique logical message key}
Content-Type: application/json
```

Body:

```json
{
  "to": "customer@example.com",
  "subject": "Your order shipped",
  "html": "<p>Your order shipped.</p>",
  "text": "Your order shipped."
}
```

The API returns `202` with a receipt. `202` means queued, not delivered. Poll the status endpoint until `accepted` or `failed`.

```python
import os
import time

import httpx

MAIL_API_URL = os.environ["MAIL_API_URL"].rstrip("/")
MAIL_API_TOKEN = os.environ["MAIL_API_TOKEN"]


def send_order_shipped(order_id: str, customer_email: str) -> None:
    payload = {
        "to": customer_email,
        "subject": f"Order {order_id} shipped",
        "text": f"Your order {order_id} has shipped.",
        "html": f"<p>Your order {order_id} has shipped.</p>",
    }
    headers = {
        "Authorization": f"Bearer {MAIL_API_TOKEN}",
        "Idempotency-Key": f"order-{order_id}-shipped",
    }
    with httpx.Client(timeout=10) as client:
        response = client.post(
            f"{MAIL_API_URL}/api/v1/app-mail/messages",
            json=payload,
            headers=headers,
        )
        if response.status_code == 202:
            return
        if response.status_code in (429, 500, 502, 503, 504):
            raise RuntimeError(f"Transient email failure: {response.status_code}")
        response.raise_for_status()
```

```javascript
const MAIL_API_URL = process.env.MAIL_API_URL.replace(/\/$/, "");
const MAIL_API_TOKEN = process.env.MAIL_API_TOKEN;

export async function sendOrderShipped(orderId, customerEmail) {
  const response = await fetch(`${MAIL_API_URL}/api/v1/app-mail/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${MAIL_API_TOKEN}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `order-${orderId}-shipped`,
    },
    body: JSON.stringify({
      to: customerEmail,
      subject: `Order ${orderId} shipped`,
      text: `Your order ${orderId} has shipped.`,
      html: `<p>Your order ${orderId} has shipped.</p>`,
    }),
  });
  if (response.status === 202) return response.json();
  throw new Error(`Email submission failed: HTTP ${response.status}`);
}
```

Operational rules:

- One recipient per request. Loop in the app for multiple recipients, with one idempotency key per logical message.
- Generate a stable `Idempotency-Key` per logical send and reuse it on retries. Reusing a key with different content returns `409`.
- Retry timeouts, `429`, and `5xx` with the same key. Do not retry `4xx` validation/authentication errors unchanged.
- Honor `Retry-After` on `429`.
- Keep the request short-lived; V-Decent's client timeout convention is 10 seconds.
- Persist the receipt `id` if the business flow needs delivery confirmation.
- Default quota is 60 messages/minute and 1,000/day per app. Batch business volume accordingly.

## 4. Receive replies and inbound mail

App Manager provisions inbound mode `webhook`. Cloudflare routes mail for the app address to a per-app Email Worker, which posts a signed JSON payload to:

```
https://<app-fqdn>/webhooks/vdecent-mail
```

Implement that endpoint to:

1. Read the raw request body before JSON parsing.
2. Verify `X-VDecent-Signature` (`sha256=<hex HMAC-SHA256 of the exact body>` using `MAIL_INBOUND_WEBHOOK_SECRET`).
3. Reject invalid signatures with `401`.
4. Deduplicate by `X-VDecent-Delivery-Id` / `deliveryId`.
5. Return `2xx` quickly; process heavy work asynchronously.
6. Store the message if the app needs an inbox/history.

If the webhook returns non-2xx, times out, or the Worker cannot deliver, the message is forwarded to the app's owner inbox instead. Inbound attachments are not forwarded at launch.

App-side reply: when the app sends a reply, call the same send API with the recipient's address. The approved address remains `From`/`Reply-To`.

## 5. Test before going live

1. Send from the app to an external inbox; expect `202`, then poll `accepted`.
2. Reply from the external inbox to the app address.
3. Confirm the webhook received the signed payload, or that the owner inbox received the fallback.
4. Confirm SPF/DKIM/DMARC pass in the received headers.
5. Test a retry by reusing the same idempotency key; expect the original receipt.
6. Test an invalid token and confirm `401` without leaking credentials to logs.

## 6. Troubleshooting

| Symptom | Check |
| --- | --- |
| `401` | Token missing, rotated, or sent from the wrong environment. |
| `403` | Email identity is not active (pending approval or suspended). |
| `409` | Idempotency key reused with different content. |
| `413` | Attachments exceed the total size limit. |
| `422` | Invalid recipient, missing body, too many/unsupported attachments, or bad subject. |
| `429` | Per-minute or daily quota; honor `Retry-After`. |
| Mail accepted but not received | Check the recipient, provider bounce, and Notification Service status endpoint. |
| Inbound not reaching the webhook | Check the public HTTPS endpoint, signature, and response status; a failure forwards to the owner inbox. |

For exact request/response fields, status lifecycle, attachment rules, signing examples, and error semantics, use the [App Email API deep dive](app-email-api-deep-dive.md).
