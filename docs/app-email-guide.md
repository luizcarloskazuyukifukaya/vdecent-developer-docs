# App Email Support

Every V-Decent app can send automated email as a real address on its own app domain and let a human receive and answer replies as that same address. The app never holds provider credentials and never runs a mail server.

## Status and provisioning

App-specific email is separate from V-Decent system email. An app can send only as its own identity. Platform addresses such as `notifications@v-decent.org` and `contact@v-decent.org` are reserved for V-Decent services and are permission-controlled separately.

| Capability | Current status | How it is enabled |
| --- | --- | --- |
| Send app email through the shared API | Available | Request an app email identity. The platform operator creates and activates it and provides `MAIL_API_URL` and `MAIL_API_TOKEN`. |
| Owner send-as over SMTP | Available, operator-assisted | The operator enables the submission listener/ingress and provides the per-identity SMTP credential; the owner configures their mail client. |
| Inbound replies forwarded to the owner inbox (Mode A) | Available, operator-assisted | The operator configures the Cloudflare Email Routing rule for the app address and verifies the owner inbox. |
| App-owned inbox webhook (Mode B) | Available, operator-assisted | The operator configures the inbound mode, webhook URL, and one-time secret. |
| Owner-facing App Manager email setup and automated Cloudflare provisioning | Planned/rolling out | Until it is available, the platform operator performs provisioning and reports the address and status. |

To request email support, provide the app name/shortname, app domain, owner inbox, and whether inbound forwarding is required. The operator returns the app address, status, and credentials.

1. [What you get](#1-what-you-get)
2. [Address model and defaults](#2-address-model-and-defaults)
3. [Environment contract](#3-environment-contract)
4. [Send automated email (API)](#4-send-automated-email-api)
5. [Owner send-as (SMTP)](#5-owner-send-as-smtp)
6. [Receiving replies (Cloudflare forwarding)](#6-receiving-replies-cloudflare-forwarding)
7. [Optional app-owned inbox](#7-optional-app-owned-inbox)
8. [Owner email-client setup](#8-owner-email-client-setup)
9. [Testing](#9-testing)
10. [Troubleshooting](#10-troubleshooting)
11. [Security and LGPD](#11-security-and-lgpd)

## 1. What you get

- One primary address per app, derived from the app shortname and app domain.
- Outbound mail through the shared Notification Service outbox, delivered by the platform's SMTP provider.
- HTML with a plain-text fallback and up to three attachments.
- Per-identity quotas and retries, plus a status endpoint scoped to your identity.
- Inbound replies forwarded to a verified owner inbox, or optionally posted to an HTTPS webhook.
- A send-as SMTP credential so the owner can answer replies from a normal mail client.

`From` and `Reply-To` always resolve to the app identity address. Your request cannot override them, and the owner's private inbox is only a routing destination — it never appears in message headers.

System addresses such as `notifications@v-decent.org` and `contact@v-decent.org` are not app identities and cannot be used by apps. They are platform senders with separate caller permissions.

## 2. Address model and defaults

An identity address is `<local-part>@<app-domain>`.

- Default local part: `contact-<shortname>`.
- Default address: `contact-<shortname>@<app-domain>`.
- The app domain is the domain selected in App Manager: `v-decent.org` by default, or the owner's custom domain.
- Display name defaults to the app name.
- One primary identity per app at launch.
- Every registered app reserves `<shortname>` and `contact-<shortname>` on its app domain, even before email is enabled; another app cannot claim those local parts on the same domain.

Local-part policy:

- Lowercase, 1–64 characters.
- Allowed characters: `a-z`, `0-9`, `.`, `_`, `-`; must start with a letter or digit.
- Uniqueness is case-insensitive within the domain.
- Reserved local parts: `support`, `notifications`, `admin`, `postmaster`, `abuse`, `mailer-daemon`, `noreply`.

Registration and changes:

- App Manager collects `email_enabled`, `email_address`, `email_owner_inbox`, and `email_display_name`. It derives and validates the default address, checks reserved names and uniqueness, and stores the configuration.
- You may change the local part on the existing app domain while it is free and not reserved.
- Any domain change, or an address outside the app domain, requires V-Decent operator approval. Custom domains also need DNS verification; inbound on a custom domain requires the domain zone to be delegated to V-Decent's Cloudflare.
- An identity becomes `active` only after destination and domain verification succeed. Until then it cannot send.
- When the App Manager email UI is enabled, app owners can see the current address, lifecycle status, and owner inbox on the application detail page. Until then, the platform operator provides that information.

## 3. Environment contract

Use these variables in your app. Keep them backend-only; never expose them in frontend build arguments or commit real values.

```dotenv
MAIL_API_URL=https://notification-api.v-decent.org
MAIL_API_TOKEN=
MAIL_FROM=contact-<shortname>@<app-domain>
MAIL_REPLY_TO=contact-<shortname>@<app-domain>
MAIL_INBOUND_MODE=forward
MAIL_INBOUND_WEBHOOK_SECRET=
```

- `MAIL_API_URL` — Notification Service base URL. Development/PoC uses `https://notification-api-dev.v-decent.org`; there is no automatic fallback.
- `MAIL_API_TOKEN` — the identity API token, shown once at creation or rotation. Backend only.
- `MAIL_FROM` / `MAIL_REPLY_TO` — your identity address.
- `MAIL_INBOUND_MODE` — `forward` (default) or `webhook`.
- `MAIL_INBOUND_WEBHOOK_SECRET` — only for `webhook` mode; the one-time secret returned when webhook mode is enabled.

The SMTP send-as password is a separate credential and should be stored as a secret for the owner, not in the app runtime.

## 4. Send automated email (API)

`POST /api/v1/app-mail/messages` requires the identity token and an idempotency key.

```bash
curl -X POST "$MAIL_API_URL/api/v1/app-mail/messages" \
  -H "Authorization: Bearer $MAIL_API_TOKEN" \
  -H "Idempotency-Key: order-1234-shipped" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "customer@example.com",
    "subject": "Your order shipped",
    "html": "<p>Your order shipped.</p>",
    "text": "Your order shipped."
  }'
```

Request fields:

- `to` — one recipient per request at launch. Loop in your app for batches and use a distinct idempotency key for each message.
- `subject` — 1–200 characters, no CR/LF.
- `html` / `text` — at least one is required; each up to 256 KB. Send both for the best client compatibility.
- `attachments` — optional, up to three. Each item is `filename`, `contentType`, and `contentBase64`. The total decoded size is capped at 5 MB. Allowed types: `application/pdf`, `image/png`, `image/jpeg`, `text/csv`, `text/plain`. There is no antivirus or content scanning at launch.

Response: HTTP `202` means durably queued, not delivered. The receipt contains `id`, `status`, `attempts`, and `last_error`.

```json
{"id": "<message UUID>", "status": "pending", "attempts": 0, "last_error": null}
```

Check a message with `GET /api/v1/app-mail/messages/{id}`. It returns the same receipt shape and only your own identity's messages; another identity's ID returns `404`. Statuses are `pending`, `accepted`, or `failed`; `muted` appears only if an operator temporarily disables the email channel. Transient failures retry after 30, 60, 120, and 240 seconds, up to five attempts; permanent rejections fail immediately. There is no replay endpoint.

Idempotency: keys are unique per identity. Reusing a key with identical content returns the original receipt; reusing a key with different content returns `409`. Retry safely after timeouts with the same key.

Error responses:

| Status | Meaning |
| --- | --- |
| `401` | Missing or invalid API token. |
| `403` | The identity is not active (suspended or not yet verified). |
| `409` | Idempotency key reused with different content. |
| `413` | Attachment payload exceeds the size limit. |
| `422` | Invalid input, such as a bad recipient, missing body, more than three attachments, or unsupported attachment type. |
| `429` | Per-minute or daily quota exhausted; honor `Retry-After`. |

Default quotas are 60 messages per minute and 1,000 per day per identity.

## 5. Owner send-as (SMTP)

The owner replies as the app address by sending through the shared submission server. The platform operator must enable the submission listener and the `smtp.v-decent.org` ingress for the environment; the per-identity credential is then issued to the owner.

| Setting | Value |
| --- | --- |
| SMTP server | `smtp.v-decent.org` |
| Port / security | `587` STARTTLS only |
| Username | The app address, e.g. `contact-<shortname>@<app-domain>` |
| Password | The per-identity SMTP credential |
| Authentication | Required |
| TLS | Required; plaintext submission is not exposed |

Port `465` (implicit TLS) is not offered by the shared listener. Supporting it
requires a future operator-provisioned implicit-TLS listener.

Rules enforced by the server:

- `MAIL FROM` and the message `From` header must match the identity address.
- If `Reply-To` is present it must also match the identity address.
- `Cc` and `Bcc` are rejected; send one recipient per message.
- Subjects are 1–200 characters; HTML and text bodies are each limited to 256 KB, matching the API.
- Accepted mail enters the same outbox and is delivered by the platform provider.
- The credential is stored hashed, works only while the identity is `active`, and can be rotated by an operator.

## 6. Receiving replies (Cloudflare forwarding)

This is Mode A and the default (`MAIL_INBOUND_MODE=forward`).

- Cloudflare Email Routing forwards the app address to the identity's verified owner inbox.
- No app changes or webhook are needed.
- The owner adds a filter or label on `To: <app address>` (or `deliveredto:` / `X-Forwarded-To`) and replies with send-as.
- V-Decent stores no message content in this mode.

The owner inbox must be verified in Cloudflare. An unverified destination breaks forwarding until the owner confirms it.

Today this is operator-assisted: the platform operator creates the Cloudflare rule for the app address and verifies the owner inbox. The planned App Manager inbound automation will perform these steps when the owner saves the email configuration; until that rollout, the operator provides the address and forwarding status.

## 7. Optional app-owned inbox

Mode B (`MAIL_INBOUND_MODE=webhook`) lets the app receive parsed replies. An operator configures the identity's inbound mode and webhook URL and returns a one-time `webhook_secret`.

- A Cloudflare Email Worker receives mail for the app address and `POST`s it to your HTTPS endpoint.
- Request headers:
  - `X-VDecent-Signature: sha256=<hex>` — HMAC-SHA256 of the raw request body using the webhook secret.
  - `X-VDecent-Delivery-Id` — the delivery identifier.
- JSON payload fields: `deliveryId`, `to`, `from`, `subject`, `text`, `html`, `headers` (allowlisted headers only), and `receivedAt`.
- No attachments are delivered at launch.
- If the webhook fails, the Worker forwards the message to the owner inbox as a fallback.

The endpoint must be public HTTPS with a valid certificate. Your app must:

- Verify `X-VDecent-Signature` on every request using a constant-time comparison; reject unsigned or stale payloads.
- Persist idempotently by `deliveryId`.
- Authenticate the owner. The inbox is never publicly readable.
- Define retention and deletion, and purge on owner request.
- Reply through the app-mail API; no direct provider credentials in the app.
- Keep full message bodies and recipient PII out of logs.
- Provide a test mode or fixture for the webhook contract.

Inbox UI, storage, spam handling, and LGPD obligations are the app owner's responsibility.

## 8. Owner email-client setup

The app sends automated mail, but the owner must configure the client that receives and answers replies.

1. **Confirm:** the identity is `active`, the owner inbox is verified, and the SMTP credential is available.
2. **Receive:** Cloudflare already forwards to the owner inbox. Add a filter or label on `To: <app address>`.
3. **Reply as the app address:** add a send-as identity using the SMTP settings in section 5.
4. **Choose a client.** Thunderbird is the recommended path. Gmail works with a caveat. Apple Mail and Outlook are unsupported at launch.
5. **Verify:** send from the app, reply from the client, and confirm the recipient sees the app address with aligned SPF, DKIM, and DMARC.

### Thunderbird (recommended)

1. Open Account Settings for the owner's existing account.
2. Under **Manage Identities**, add an identity with the app address and display name.
3. Set the outgoing server (SMTP) to `smtp.v-decent.org`, port `587` with STARTTLS, username = app address, authentication = normal password.
4. Set the identity's From and Reply-To to the app address.
5. Send a test reply from the app address and confirm delivery and alignment.

Thunderbird works with the owner's existing inbox, so no new incoming server is needed.

### Gmail

1. In Gmail, open **Settings → Accounts and Import → Send mail as**.
2. Add the app address as another address you own.
3. Use `smtp.v-decent.org`, port `587` STARTTLS, username = app address, password = SMTP credential.
4. The verification code is delivered through Cloudflare to the owner inbox; enter it to finish.
5. Set the app address as the default for replies to app mail.

**January 2027 caveat:** Google has announced the withdrawal of third-party Gmail "Send Mail As" in January 2027. Treat the Gmail web send-as path as temporary and plan a move to Thunderbird (or the optional app-owned inbox) before then. Automated app mail and Cloudflare forwarding are independent of this Gmail feature.

### Apple Mail and Outlook

These clients generally require an incoming server before they will add a send-as identity, and V-Decent does not provide a hosted mailbox or IMAP service. They are unsupported for send-as at launch. Point owners to Thunderbird or the optional app-owned inbox.

## 9. Testing

1. Confirm the identity is `active` and the owner inbox is verified.
2. Submit a test message with `curl` or your app code, and keep the returned `id`.
3. Poll `GET /api/v1/app-mail/messages/{id}` until the status is `accepted` or `failed`; inspect `last_error` on failure.
4. Reply to the message from a different external inbox, then confirm the reply reaches the owner inbox (Mode A) or your webhook (Mode B).
5. In webhook mode, verify the signature against the raw body and replay the same `deliveryId` to confirm idempotency.
6. Send a reply from the owner client and confirm the external recipient sees the app address.
7. Check SPF, DKIM, and DMARC alignment in the received headers.

Use a different sending inbox for inbound tests. Some providers discard a message forwarded back to the same account that sent it, so a missing same-account test does not prove routing is broken.

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `401` from the API | Missing, wrong, or rotated `MAIL_API_TOKEN`. | Use the current token; rotate and redeploy if lost. |
| `403` from the API | Identity not `active` or suspended. | Wait for destination/domain verification or ask the operator to reactivate. |
| `409` from the API | Same idempotency key with different content. | Use a new key per distinct message. |
| `413` from the API | Attachment payload exceeds 5 MB total. | Reduce or split attachments. |
| `422` from the API | More than three attachments, unsupported type, or invalid field. | Reduce attachments or use an allowed type. |
| `429` from the API | Per-minute or daily quota exhausted. | Back off using `Retry-After`. |
| Mail not arriving in the owner inbox | Cloudflare destination not verified. | Owner confirms the destination verification email. |
| Reply rejected by SMTP | `From` or `MAIL FROM` does not match the identity, or more than one recipient. | Send as the app address to one recipient per message. |
| SMTP authentication fails | Wrong credential, or the identity is not active. | Use the current credential; ask the operator to rotate or reactivate. |
| Duplicate SPF records | More than one `v=spf1` record at the same DNS name. | Merge into a single SPF record; never add a second. |
| Gmail shows "on behalf of" | Sender is not aligned with the From domain. | Use the SMTP server for this domain and confirm SPF/DKIM/DMARC alignment; check the January 2027 caveat. |
| Apple Mail / Outlook cannot add send-as | Client requires an incoming server. | Use Thunderbird or the optional app-owned inbox. |

## 11. Security and LGPD

- API tokens and SMTP credentials are random, stored hashed, compared in constant time, and shown once. A lost secret must be rotated.
- Credentials are scoped to one identity. `From` and `Reply-To` are derived from the identity and never trusted from request input.
- CR/LF is rejected in subjects, display names, and addresses. Recipients are validated.
- Caller isolation applies: an app can read only its own message records. Identity administration is operator-only.
- Message bodies and attachments are transient and purged after a default 7-day delivery retention. Minimal metadata is kept for audit.
- Recipient addresses are personal data (PII). Restrict database access, encrypt backups, redact logs and errors, and never log full message bodies.
- In forwarding mode V-Decent stores no message content. In webhook mode the app owner controls storage, retention, access, and deletion, and owns the corresponding LGPD obligations.
- Report a lost credential or suspected abuse to the V-Decent operator immediately.
