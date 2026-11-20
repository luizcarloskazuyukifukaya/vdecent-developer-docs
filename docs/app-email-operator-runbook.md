# App Email Operator Runbook

Operator procedures for provisioning, verifying, rotating, suspending, and
decommissioning per-app email identities. The developer-facing contract is in
[App Email Support](app-email-guide.md); this document covers the operator side.

1. [Preconditions and approvals](#1-preconditions-and-approvals)
2. [Create or verify the identity](#2-create-or-verify-the-identity)
3. [Default v-decent.org provisioning](#3-default-v-decentorg-provisioning)
4. [Custom-domain provisioning](#4-custom-domain-provisioning-nameserver-delegation)
5. [Cloudflare Email Routing records](#5-cloudflare-email-routing-records)
6. [Resend DKIM, SPF, DMARC, and duplicate-SPF rule](#6-resend-dkim-spf-dmarc-and-duplicate-spf-rule)
7. [Owner inbox verification](#7-owner-inbox-verification)
8. [Credential handover and rotation](#8-credential-handover-and-rotation)
9. [Suspension and decommission](#9-suspension-and-decommission)
10. [Escalation and rollback](#10-escalation-and-rollback)
11. [Reference Cloudflare Email Worker (Mode B)](#11-reference-cloudflare-email-worker-mode-b)

Never place tokens, SMTP passwords, webhook secrets, or real provider
credentials in this repository, tickets, chat, logs, or screenshots. Provider-
returned DKIM public keys are public DNS data; API keys and passwords are not.

## 1. Preconditions and approvals

Confirm all of the following before touching DNS or the Notification Service:

- The app is registered in App Manager and the owner supplied
  `email_enabled`, `email_address`, `email_owner_inbox`, and
  `email_display_name`.
- App Manager derived the default address from the app shortname and app domain
  and validated format, reserved local parts, and uniqueness.
- The owner controls the destination inbox and, for a custom domain, can prove
  domain ownership or delegate its nameservers.
- The Notification Service operator account has the ops-admin role. Every
  identity endpoint requires `require_ops_admin`; there is no app-facing
  administration API.
- A rollback owner and a maintenance window exist for custom-domain changes.

Address rule: the default identity is `contact-<shortname>@<domain>`, where
`<shortname>` is the app shortname and `<domain>` is the app domain selected in
App Manager (`v-decent.org` by default). Local parts are lowercase, 1–64
characters, limited to `a-z`, `0-9`, `.`, `_`, and `-`, start with a letter or
digit, and are unique case-insensitively within the domain. Reserved local
parts: `support`, `notifications`, `admin`, `postmaster`, `abuse`,
`mailer-daemon`, `noreply`.

### Approval gate for domain changes

Any domain change, any address outside the app domain, any custom-domain
onboarding, and any nameserver delegation requires explicit V-Decent operator
approval before execution. The approval record must contain:

- requester, approver, date/time, and the exact old and new address/domain;
- why the app domain cannot be used;
- the DNS/Cloudflare/Resend changes planned;
- the rollback plan and the verification owner.

A local-part change on the existing app domain is allowed without domain
approval when the new local part is free, not reserved, and the identity is not
suspended. It still needs re-verification and an audit entry. Pause and escalate
if ownership, delegation, or the approval record is ambiguous.

## 2. Create or verify the identity

Base URL: `https://notification-api.v-decent.org` in Production and
`https://notification-api-dev.v-decent.org` in Development/PoC. There is no
automatic fallback between them.

### Identity administration endpoints

All paths below are under `/api/v1` and require an ops-admin session.

| Method | Path | Purpose | Request body |
| --- | --- | --- | --- |
| `POST` | `/app-mail/identities` | Create identity | `app_name`, `address`, `display_name`, `owner_inbox`, optional `quota_per_minute` (default 60), optional `quota_per_day` (default 1000) |
| `GET` | `/app-mail/identities` | List identities | — |
| `POST` | `/app-mail/identities/{id}/rotate` | Rotate both credentials | — |
| `PATCH` | `/app-mail/identities/{id}` | Change status | `status`: `pending_destination`, `active`, `suspended`, or `inactive` |
| `PUT` | `/app-mail/identities/{id}/inbound` | Set inbound mode | `mode`: `forward` or `webhook`; optional `webhook_url`; optional `fallback_inbox` |
| `DELETE` | `/app-mail/identities/{id}` | Delete identity | — |

Create returns HTTP `201` with `id`, `status` (`pending_destination`),
`api_token`, and `smtp_password`. Rotate returns `id`, `status`, a new
`api_token`, and a new `smtp_password`. Inbound update returns `mode` and, for
webhook mode, a new `webhook_secret`; forward mode returns `webhook_secret:
null`.

Create only after the address is approved and reserved. Uniqueness conflicts
return `409`; invalid address, owner inbox, or quota values return `422`.
`DELETE` returns `204`, or `409` while the identity still has pending
notifications.

Status values are exact:

- `pending_destination` — created, destination/domain not verified, cannot send.
- `active` — verified and allowed to send through the API and SMTP.
- `suspended` — operator hold; API and SMTP authentication fail.
- `inactive` — retired identity retained for records.

### One-time secret rule

`api_token`, `smtp_password`, and `webhook_secret` are returned only in the
create, rotate, or inbound-update response. The service stores only hashes.
Copy each secret directly into the password manager or the deployment secret
store in the same operation; never log the response body, paste it into chat, or
commit it. A secret that is lost, exposed, or not captured is rotated, not
recovered.

### Verification

```bash
curl -sS "$MAIL_API_URL/api/v1/app-mail/identities" \
  -H "Authorization: Bearer $OPS_ADMIN_TOKEN"
```

Confirm exactly one row per app, the intended address, owner inbox, and status.
Do not set `active` until steps 5–7 pass.

## 3. Default v-decent.org provisioning

Default apps do not need a nameserver change. V-Decent already hosts the
`v-decent.org` zone and has Cloudflare Email Routing and the Resend sending
domain configured.

1. Confirm `email_address` is `contact-<shortname>@v-decent.org` and the local
   part is free.
2. If `v-decent.org` is already verified in Resend and Email Routing is enabled,
   skip to step 4.
3. From section 5, confirm the Cloudflare routing records exist; from section 6,
   confirm the Resend records and DMARC policy exist.
4. Create the Cloudflare Email Routing custom address from section 5.
5. Create the Notification Service identity from section 2. Copy both secrets.
6. Hand over credentials per section 8 and set the app environment variables.
7. Verify the owner inbox per section 7.
8. Set status to `active` only after verification succeeds.
9. Record operator, timestamp, address, DNS/provider changes, and approval
   reference in the audit log.

## 4. Custom-domain provisioning (nameserver delegation)

Use this path only with an approved domain change.

- Inbound on a custom domain requires the domain zone to be delegated to
  V-Decent's Cloudflare. Without delegation, Cloudflare cannot add the root MX
  records and cannot receive mail for the domain.
- Outbound-only custom domains can work with DNS records alone: the owner adds
  the Resend records (section 6) at their DNS provider and no nameserver change
  is required. The owner then replies with the owner client through
  `smtp.v-decent.org`.

Delegation steps:

1. Obtain the approval record from section 1. Export and store the current DNS
   snapshot outside Git before changes.
2. Add the zone in the V-Decent Cloudflare account and note the assigned
   nameservers.
3. Have the owner replace the domain's nameservers at the registrar with those
   assigned nameservers. Do not change the registrar's registrant or contact
   data unless the owner asks.
4. Confirm delegation and propagation:

   ```bash
   dig +short NS example.com
   dig +short MX example.com
   ```

   Expected NS answers are the Cloudflare nameservers assigned to the zone.
   Propagation can take up to 24 hours; do not proceed on stale answers.
5. Enable Cloudflare Email Routing for the zone (section 5).
6. Add the domain to Resend and install the exact DKIM, SPF, and DMARC records
   Resend returns (section 6). Trigger verification and wait for `verified`.
7. Create the custom address and verify the destination (sections 5 and 7).
8. Create the identity, hand over credentials, and activate only after both
   domain and destination verification pass.

If the owner cannot delegate nameservers and only needs outbound, stop at the
Resend records and document that inbound is unsupported for that domain.

## 5. Cloudflare Email Routing records

Email Routing is the inbound path (Mode A default, and the Mode B fallback).
These records live on the root domain and are managed by Cloudflare. Prefer
onboarding so Cloudflare writes and locks them; do not hand-edit locked records.

### Cloudflare Email Routing record table

| Type | Name | Value | Priority | Notes |
| --- | --- | --- | --- | --- |
| `MX` | `@` | `route1.mx.cloudflare.net` | Auto (Cloudflare-managed) | Inbound routing; root MX must belong to Cloudflare. |
| `MX` | `@` | `route2.mx.cloudflare.net` | Auto (Cloudflare-managed) | Same routing set. |
| `MX` | `@` | `route3.mx.cloudflare.net` | Auto (Cloudflare-managed) | Same routing set. |
| `TXT` | `@` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — | Only when no SPF exists; otherwise merge the include. Exactly one SPF record at `@`. |
| `TXT` | `cf2024-1._domainkey` | `v=DKIM1; h=sha256; k=rsa; p=<Cloudflare-provided public key>` | — | Routing DKIM selector; value comes from the Email Routing dashboard. |
| `TXT` | `_dmarc` | `v=DMARC1; p=none; rua=mailto:<dmarc-report-inbox>` | — | Start non-enforcing; tighten only after evidence. |

Notes:

- Cloudflare routing MX cannot coexist with another provider's root MX. If a
  previous mailbox provider owns the root MX, obtain approval and migrate before
  enabling routing.
- The routing DKIM selector `cf2024-1` is separate from Resend's
  `resend` selector; both can exist.
- Locked records cannot be edited or deleted until unlocked under Email Routing
  settings. Unlock only during an approved migration.

### Custom address rule

Create a Cloudflare Email Routing custom address for every app identity:

| Field | Value |
| --- | --- |
| Custom address | `<local-part>` (for example `contact-<shortname>`) |
| Domain | The app domain (`v-decent.org` or the delegated custom domain) |
| Action | Send to |
| Destination | The identity's `owner_inbox` |

The resulting address must equal `contact-<shortname>@<domain>` unless an
approved local-part change applies. A custom address routes inbound mail only;
outbound is handled by Resend through the Notification Service.

For Mode B, add a second rule or Worker route for the same address that invokes
the Email Worker (section 11) and falls back to the verified owner inbox.

Validate records:

```bash
dig +short MX example.com
dig +short TXT example.com
dig +short TXT cf2024-1._domainkey.example.com
dig +short TXT _dmarc.example.com
```

## 6. Resend DKIM, SPF, DMARC, and duplicate-SPF rule

Resend is the outbound provider. Use the exact records the Resend dashboard
shows for the domain and region; the names and shapes below are the contract,
while the region, DKIM key, and any newer CNAME variants come from the dashboard.
Never guess, truncate, or reformat a DKIM value.

### Resend record table

| Type | Name | Value | Priority | Notes |
| --- | --- | --- | --- | --- |
| `MX` | `send` | `feedback-smtp.<region>.amazonses.com` | `10` (or the dashboard value) | Bounce/complaint return path. Region must match the Resend domain region. |
| `TXT` | `send` | `v=spf1 include:amazonses.com ~all` | — | Resend SPF for the return-path subdomain. |
| `TXT` | `resend._domainkey` | `p=<Resend-provided DKIM public key>` | — | DKIM signing key; must match the dashboard exactly. |
| `TXT` | `_dmarc` | `v=DMARC1; p=none; rua=mailto:<dmarc-report-inbox>` | — | One DMARC record per domain; start with `p=none`. |

For domains created after August 2026, Resend may return CNAME records on `send`
and `rsend` instead of the MX/TXT pair. Publish whatever the domain's Records tab
lists; do not mix the two shapes. On Cloudflare, DKIM records must be DNS-only
(grey cloud), never proxied.

### Duplicate SPF rule

There must be exactly one `v=spf1` TXT record at any DNS name. A duplicate SPF
record is a configuration error and can invalidate both records, causing SPF
failures for routing and outbound mail.

- Root `@` carries the Cloudflare routing SPF.
- `send` carries the Resend return-path SPF.
- These are different names, so both records are expected.
- If the root already has an SPF record, merge the Cloudflare include into that
  single record instead of adding a second one, for example:
  `v=spf1 include:_spf.mx.cloudflare.net include:<other-sender> ~all`.
- Keep total SPF DNS lookups at or below 10. Remove or flatten non-essential
  includes rather than adding a second record.

### DMARC

Start every new custom domain at `p=none` with a monitored report address. Do
not publish `p=quarantine` or `p=reject` before confirming SPF and DKIM alignment
for legitimate app mail and owner replies. DMARC passing does not by itself mean
an enforcing policy is safe.

### Verification

```bash
dig +short TXT send.example.com
dig +short MX send.example.com
dig +short TXT resend._domainkey.example.com
dig +short TXT _dmarc.example.com
```

Resend must report the domain as `verified` before the identity becomes
`active`. A `verified` Resend domain and a verified Cloudflare destination are
separate checks.

## 7. Owner inbox verification

Cloudflare requires the destination address to confirm forwarding. An
unverified destination breaks inbound delivery even when all DNS records are
correct.

1. In Cloudflare Email Routing, add the owner inbox as a destination.
2. Cloudflare sends a verification email to that inbox. The owner clicks the
   confirmation link.
3. Re-read the destination and confirm it is verified.
4. If the inbox changes, add and verify the new destination first, update the
   routing rule, confirm a test message, then remove the old destination.
5. For Mode B, verify the fallback inbox as well; it receives the message when
   the app webhook fails.

A test message sent from a different external inbox is the only proof of
delivery. Do not infer forwarding success from DNS alone, and do not test by
forwarding back to the same account that sent the message.

## 8. Credential handover and rotation

Each identity has two independent secrets:

- `api_token` — backend-only token for `POST /api/v1/app-mail/messages` and
  `GET /api/v1/app-mail/messages/{id}`.
- `smtp_password` — owner send-as password for `smtp.v-decent.org`, port `587`
  STARTTLS or `465` SSL, username equal to the app address.

Handover:

1. Copy both secrets from the create response directly into the password
   manager. Never send them by email, chat, ticket, or commit.
2. Give the app runtime only `MAIL_API_TOKEN`; store it as a backend secret in
   the deployment platform. Set `MAIL_API_URL`, `MAIL_FROM`, `MAIL_REPLY_TO`,
   `MAIL_INBOUND_MODE`, and, for webhook mode, `MAIL_INBOUND_WEBHOOK_SECRET`.
3. Give the owner only the SMTP password and client settings; the owner does not
   receive the API token.
4. For webhook mode, give the Worker only `APP_MAIL_WEBHOOK_SECRET`; do not put
   the identity API token in the Worker.

Rotation:

```bash
curl -sS -X POST "$MAIL_API_URL/api/v1/app-mail/identities/$IDENTITY_ID/rotate" \
  -H "Authorization: Bearer $OPS_ADMIN_TOKEN"
```

- Rotate invalidates the previous API token and SMTP password together. There is
  no partial rotation endpoint.
- Update the app runtime secret and redeploy before the old token stops working;
  update the owner's mail client with the new SMTP password.
- Re-enabling webhook mode with `PUT /app-mail/identities/{id}/inbound` issues a
  new `webhook_secret`; update the Worker variable in the same change.
- Rotate on suspected exposure, on owner change, and on the platform's scheduled
  credential cadence.
- Record the rotation, actor, and time in the audit log. Do not record the
  secret.

SMTP brute force: the Notification Service adds a 1-second delay on failed SMTP
authentication. That delay is a floor, not the primary control. Ingress rate
limiting at the edge/proxy is the real guard against credential brute force and
must remain enabled for the SMTP submission path.

## 9. Suspension and decommission

### Suspend or reactivate

```bash
curl -sS -X PATCH "$MAIL_API_URL/api/v1/app-mail/identities/$IDENTITY_ID" \
  -H "Authorization: Bearer $OPS_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "suspended"}'
```

Suspension stops API sends and SMTP authentication immediately; existing
routing is untouched. Use `inactive` for a retired identity that must be kept for
records. Reactivate with `active` only after re-verifying the owner inbox and
domain; use `pending_destination` when verification must be redone.

### Decommission checklist

Perform in order. Stop and escalate if any step fails.

1. Suspend the identity (`status: suspended`) to stop new sends.
2. Confirm no notifications are pending for the identity. `DELETE` returns `409`
   until the queue drains; do not force-delete around pending mail.
3. Revoke both credentials by deleting the identity (step 6) or by rotating and
   discarding the new secrets if a short retention record is required.
4. Delete the Cloudflare Email Routing custom address for the app address.
5. Delete the owner destination if no other identity uses it.
6. Remove Cloudflare DNS records only when the domain is not shared. On a shared
   `v-decent.org` zone, keep the shared routing MX/SPF/DKIM and remove only the
   app-specific custom address.
7. Remove the domain from Resend only when no other identity uses that domain.
   Removing a shared sending domain breaks every other app on it.
8. Delete the identity:

   ```bash
   curl -sS -X DELETE "$MAIL_API_URL/api/v1/app-mail/identities/$IDENTITY_ID" \
     -H "Authorization: Bearer $OPS_ADMIN_TOKEN"
   ```

   Expected `204`. The service deletes the inbound config, nulls audit identity
   references, and retains audit rows.
9. Remove the app's mail environment variables and redeploy so no stale token
   remains.
10. Remove the owner's send-as identity from the mail client or password manager.
11. Record the decommission actor, timestamp, address, and every DNS/provider
    change in the audit log.

## 10. Escalation and rollback

### Escalation

- Identity, API, SMTP, quota, or webhook faults: Notification Service operator.
- DNS, Email Routing, or nameserver faults: V-Decent Cloudflare administrator.
- Domain verification, DKIM, bounce, or reputation faults: Resend account owner.
- Suspected credential exposure or abuse: suspend the identity first, then
  escalate through the V-Decent incident channel with the identity ID, address,
  timestamps, and audit entries. Do not include secrets or message bodies.

Record the incident reference in the identity audit notes.

### Rollback

- Wrong identity or address: suspend, fix the Cloudflare custom address and the
  identity record, rotate credentials, re-verify, reactivate. Do not reuse old
  secrets.
- Bad app deployment: restore the previous app revision and its previous valid
  secret; rotate if the secret was exposed.
- Bad inbound routing: restore the prior Cloudflare rule and destination from
  the pre-change snapshot. Preserve existing routing records; do not delete the
  shared root MX set while diagnosing.
- Bad DNS change on a custom domain: restore the exact previous record values
  from the snapshot, then re-check with `dig`. Allow for TTL/propagation.
- Resend domain removal is not an instant rollback. Re-add the domain, restore
  the exact DKIM/SPF/DMARC records, and re-verify before reactivating.
- Database or queue rollback: preserve the database volume and pending records.
  Do not blindly roll back migrations or resend accepted messages.

### Post-change verification

1. Identity status is `active` and the API token authenticates.
2. Owner inbox is verified and a test message from a different external inbox
   arrives.
3. A reply sent from the owner client through `smtp.v-decent.org` reaches the
   external recipient as the app address.
4. Received headers show aligned SPF, DKIM, and DMARC; no duplicate SPF record is
   present.
5. Mode B: the app verifies `X-VDecent-Signature` against the raw body, survives
   a replayed `deliveryId`, and receives the fallback when the webhook returns
   non-2xx.
6. `GET /api/v1/app-mail/messages/{id}` reaches `accepted` for the test message.

## 11. Reference Cloudflare Email Worker (Mode B)

Mode B makes the app the inbox owner. The Worker runs on the same app address,
posts a signed JSON payload to the app webhook, and forwards to the verified
owner inbox when the app fails. Attachments are not forwarded in Mode B at
launch; the payload contains only the text/HTML body and allowlisted headers.

### Worker variables

| Variable | Purpose |
| --- | --- |
| `APP_MAIL_WEBHOOK_URL` | Public HTTPS app endpoint that accepts the signed payload. |
| `APP_MAIL_WEBHOOK_SECRET` | One-time secret from the inbound update; used for HMAC-SHA256. |
| `APP_MAIL_FALLBACK_INBOX` | Verified owner inbox used when the POST fails. |

Set the same secret only in the Worker and the app that verifies it. The Worker
does not need the identity API token or SMTP password. Configure the identity
first with `PUT /api/v1/app-mail/identities/{id}/inbound` using `mode: webhook`,
the same `webhook_url`, and the `fallback_inbox`.

### Reference script

```javascript
import PostalMime from "postal-mime";

const ALLOWED_HEADERS = [
  "message-id",
  "date",
  "from",
  "to",
  "cc",
  "reply-to",
  "subject",
  "in-reply-to",
  "references",
];

export default {
  async email(message, env, ctx) {
    const fallbackInbox = env.APP_MAIL_FALLBACK_INBOX;
    try {
      const parsed = await PostalMime.parse(message.raw);

      const headers = {};
      for (const name of ALLOWED_HEADERS) {
        const value = message.headers.get(name);
        if (value) headers[name] = value;
      }

      const payload = {
        deliveryId: message.headers.get("message-id") || crypto.randomUUID(),
        to: message.to,
        from: message.from,
        subject: parsed.subject || "",
        text: parsed.text || "",
        html: parsed.html || "",
        headers,
        receivedAt: new Date().toISOString(),
      };

      const body = JSON.stringify(payload);
      const signature = await hmacSha256(env.APP_MAIL_WEBHOOK_SECRET, body);

      const response = await fetch(env.APP_MAIL_WEBHOOK_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-VDecent-Signature": signature,
          "X-VDecent-Delivery-Id": payload.deliveryId,
        },
        body,
      });

      if (!response.ok) {
        throw new Error(`App webhook returned HTTP ${response.status}`);
      }
    } catch (error) {
      if (!fallbackInbox) {
        throw error;
      }
      await message.forward(fallbackInbox);
    }
  },
};

async function hmacSha256(secret, body) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  const hex = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `sha256=${hex}`;
}
```

Deployment notes:

- `postal-mime` is a Worker module dependency; add it to the Worker project and
  deploy with Wrangler.
- The header is `X-VDecent-Signature: sha256=<hex>`, an HMAC-SHA256 of the exact
  JSON string sent as the body, not of a re-serialized object. The app must
  verify the raw request body before parsing.
- Treat any non-2xx response, network error, or timeout as failure and forward to
  the fallback inbox. Do not retry in a loop inside the Worker.
- Keep `X-VDecent-Delivery-Id` stable across retries; use it for app-side
  idempotency. The `message-id` header is the preferred source, with a random
  UUID as the fallback.
- The app must authenticate the owner and keep the inbox private; the Worker only
  delivers, it does not implement retention or access control.
- Worker logs must not contain message bodies, recipient addresses, or the
  secret.
