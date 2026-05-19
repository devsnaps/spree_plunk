# Spree Plunk

`spree_plunk` is a Spree Commerce extension that connects a Spree store to Plunk for server-side contact sync and consent-safe event tracking.

It is built for marketing use cases such as workflows, campaigns, and audience segmentation. Transactional emails such as order confirmations, shipment updates, refunds, and password resets still stay with Spree/Rails by default.

## What This Extension Does

- syncs Spree users and newsletter subscribers into Plunk contacts
- refreshes Plunk contact data when user or address records change
- tracks selected Spree commerce events into Plunk for workflows and segmentation
- keeps marketing consent explicit instead of inferring it from behavioral events
- supports both hosted Plunk and self-hosted Plunk through a configurable base API URL
- can optionally accept unsubscribe callbacks from Plunk and write them back into Spree

## Current Features

### Contact Sync

The extension currently syncs contact state from these Spree-side sources:

- user created
- user updated
- address created
- address updated
- newsletter subscriber created
- newsletter subscriber verified
- newsletter subscriber deleted

The contact payload can include:

- `email`
- `subscribed`
- `external_user_id`
- `store_code`
- `first_name`
- `last_name`
- `phone`
- `accepts_email_marketing`
- `city`
- `region`
- `country`
- `zip`
- `order_count`
- `last_order_number`
- `last_order_total`

### Event Tracking

The extension currently sends these namespaced events to Plunk:

- `spree.newsletter.subscribed`
- `spree.newsletter.unsubscribed`
- `spree.order.completed`
- `spree.order.canceled`
- `spree.shipment.shipped`
- `spree.reimbursement.paid`

These events are intended for:

- workflow triggers
- segmentation
- lifecycle automation
- post-purchase marketing flows

### Admin And Operations

- Spree admin integration form for Plunk credentials and base URL
- connectivity check against the Plunk API
- optional default sender fields for future use
- optional public API key storage, intentionally unused by the current server-side MVP
- optional inbound unsubscribe webhook guarded by a bearer token
- duplicate-delivery protection for webhook intake
- retry/discard classification for async sync failures
- structured error reporting through `Rails.error.report`

## Installation

Install the extension in the host Spree app and run the generator:

```bash
bundle exec rails generate spree_plunk:install
```

After installation:

1. Open Spree Admin.
2. Create or edit the Plunk integration for the target store.
3. Add the Plunk base URL and secret API key.
4. Verify contact sync and event tracking in a non-production environment first.

## Spree Admin Configuration

The current admin form exposes these fields.

| Field | Required | What to enter | Notes |
| --- | --- | --- | --- |
| `Plunk Base URL` | Yes | The Plunk API base URL, such as `https://next-api.useplunk.com` or your self-hosted API base like `https://plunk.example.com/api` | Use the API base only. Do not paste `/contacts`, `/events/track`, or `/v1/track`. |
| `Secret API Key` | Yes | A Plunk secret server key for the workspace, typically `sk_*` | This is the only key the current server-side integration needs for contact upsert, unsubscribe, and event tracking. |
| `Public API Key` | No | An optional browser/public key, typically `pk_*` | Stored only for future use. The current server-side MVP does not use it. |
| `Default Sender Email` | No | A mailbox such as `marketing@example.com` | Stored for future sender-related features. It does not change current sync or event tracking behavior on its own. |
| `Default Sender Name` | No | A display name such as `Example Store` | If you set this, also set `Default Sender Email` so the stored sender identity is complete. |
| `Enable Unsubscribe Webhook` | No | Check this only if you want Plunk unsubscribe events to write back into Spree | Disabled by default. |
| `Unsubscribe Webhook Authorization Token` | Required only when webhook is enabled | A shared secret that you generate yourself | Plunk will send this back in the `Authorization` header as `Bearer <token>`. |

### Where Each Value Comes From

#### Plunk Base URL

- Hosted Plunk uses `https://next-api.useplunk.com`.
- Self-hosted Plunk should use the API base URL that serves endpoints like `/contacts` and `/events/track`.
- Do not paste a full endpoint path into the field.

#### Secret API Key

- Use a secret server key from the target Plunk workspace.
- The current extension talks to `POST /contacts` and `POST /events/track`, so it needs the secret key, not the public key.
- A public `pk_*` key will fail the connection check.

#### Public API Key

- Leave this blank unless you are preparing a later browser-side or storefront integration.
- Storing the value here does not enable client-side tracking by itself.

#### Default Sender Email and Name

- These fields are placeholders for future sender-aware behavior.
- They are safe to leave blank in the current MVP.
- They do not affect current contact sync, newsletter sync, or event tracking.

## Recommended Setup Flow

1. In Plunk, confirm that you have a usable secret API key for the correct workspace.
2. In Spree Admin, set `Plunk Base URL` and `Secret API Key`.
3. Run the built-in connection check from the admin UI.
4. Create or update a newsletter subscriber in Spree and confirm that a Plunk contact is created.
5. Complete a test order and confirm that Plunk receives `spree.order.completed`.
6. Enable the inbound unsubscribe webhook only after the outbound contact sync path is already behaving correctly.

## API Strategy

The current server-side integration intentionally uses:

- `POST /contacts` for contact upsert
- `POST /contacts` with explicit `subscribed: true` for subscribe flows
- `POST /contacts` with explicit `subscribed: false` for unsubscribe flows
- `POST /events/track` for event delivery after the contact has been ensured

This extension does not rely on `/v1/track` for server-side commerce sync. The reason is important: Plunk documents that `/v1/track` can auto-create a contact, and contacts created that way are subscribed by default. The extension avoids that path so consent stays explicit.

## Consent And Safety Rules

- behavioral activity does not imply marketing consent
- only explicit newsletter opt-in should set `subscribed: true`
- user, checkout, and order-backed contact creation should stay unsubscribed unless consent is known
- commerce events should preserve an existing customer consent state instead of downgrading or upgrading it implicitly
- the unsubscribe webhook is disabled by default
- webhook writeback only accepts unsubscribe semantics and no-ops safely when the local email cannot be matched

## Inbound Unsubscribe Webhook

When enabled, the extension can receive a Plunk unsubscribe webhook and apply that change locally.

Current behavior:

- requires explicit operator opt-in
- requires an authorization bearer token
- accepts `contact.unsubscribed` semantics only
- looks up the local email in Spree
- removes the matching newsletter subscriber when present
- clears `accepts_email_marketing` on the matching user when applicable
- suppresses Spree event publication during the local writeback to avoid immediate echo loops
- ignores duplicate deliveries using replay protection
- safely no-ops when the email does not exist locally

### How The Webhook Works

The endpoint is:

```text
POST /plunk/webhooks/unsubscribe/:integration_id
```

The request flow is:

1. Spree finds the active Plunk integration by `integration_id`.
2. The webhook must be enabled for that integration or the endpoint returns `404`.
3. Spree checks the `Authorization` header and requires an exact bearer-token match.
4. Spree accepts the request only if the payload clearly indicates unsubscribe semantics.
5. Spree resolves the contact email and applies a local unsubscribe writeback.
6. Duplicate deliveries are ignored so the endpoint stays idempotent.

The current webhook processor accepts these signals as proof of unsubscribe:

- `contact.subscribed: false`
- top-level `subscribed: false`
- event name `contact.unsubscribed`

The current implementation prefers the default Plunk webhook payload and extracts the email from:

- `contact.email`
- or top-level `email`

### How To Get The `Unsubscribe Webhook Authorization Token`

This token is not issued by Plunk.

It is a shared secret that you generate yourself and configure in both places:

1. Store it in Spree Admin as `Unsubscribe Webhook Authorization Token`.
2. Send the same value from the Plunk webhook step as:

```text
Authorization: Bearer your-secret-token
```

Example:

- Spree field `Unsubscribe Webhook Authorization Token`:
  - `12b61441e2177ef63ff91623a2c8da531c97bac8890172530f8c90a2ffb3012e`
- Plunk webhook header:
  - Name: `Authorization`
  - Value: `Bearer 12b61441e2177ef63ff91623a2c8da531c97bac8890172530f8c90a2ffb3012e`

Do not put `Bearer` in the header name field. The header name must be `Authorization`, and the `Bearer ` prefix belongs at the start of the header value.

Use a strong random value, for example:

```bash
openssl rand -hex 32
```

or:

```bash
ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
```

### How To Configure The Webhook In Plunk

Plunk's own webhook guidance matches the shape this extension expects: use a workflow triggered by `contact.unsubscribed`, send a public HTTP request, and authenticate it with a shared-secret header.

Recommended setup:

1. Save the Spree integration first so you have the integration-specific webhook URL.
2. In Plunk, create a workflow triggered by `contact.unsubscribed`.
3. Add a `Webhook` step.
4. Set the URL to your public Spree endpoint. Use the exact integration-specific path shown in Spree Admin after you save the integration. In current Spree, integrations use prefixed params that normally look like `int_<encoded-id>`, so the final URL will usually look like:

   ```text
   https://your-spree-host.example.com/plunk/webhooks/unsubscribe/int_25Rf07xd9z
   ```

   The `int_25Rf07xd9z` part is not something you invent manually. It is the saved integration's `to_param`, and you can usually copy it directly from:

   - the webhook path shown in the Spree Admin form after saving the integration
   - or the integration edit URL, which typically looks like `/admin/integrations/int_25Rf07xd9z/edit`

5. Set the method to `POST`.
6. Add this header:

   ```json
   {
     "Authorization": "Bearer your-secret-token"
   }
   ```

   In the Plunk UI, that means:

   - `Name`: `Authorization`
   - `Value`: `Bearer your-secret-token`

7. Leave the body empty so Plunk sends its default payload.
8. Enable the workflow.

Notes:

- The webhook URL must be publicly reachable from Plunk.
- HTTPS is preferred.
- Plunk webhook delivery is workflow-based, so no workflow means no webhook.
- This extension is built to work with Plunk's default webhook payload shape.
- If you choose a custom webhook body, it still needs to include unsubscribe semantics plus the contact email.

### Expected Local Result After A Successful Plunk Unsubscribe

If Plunk flips a contact to unsubscribed and the webhook is configured correctly:

- the matching `Spree::NewsletterSubscriber` row is deleted when present
- the matching user's `accepts_email_marketing` becomes `false` when supported
- repeating the same delivery should stay safe and idempotent

## What This Extension Is For

This extension is a good fit when you want:

- Plunk to own marketing automation
- Spree customer and newsletter data to stay in sync with Plunk
- commerce events available inside Plunk workflows
- a consent-safe server-side integration without browser tracking as a requirement

## Out Of Scope

The current MVP intentionally does not cover:

- transactional email migration into Plunk
- anonymous visitor tracking
- storefront public-key or browser-side tracking
- back-in-stock workflow parity
- campaign or workflow authoring inside Spree admin
