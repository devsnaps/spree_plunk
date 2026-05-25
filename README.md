# Spree Plunk

`spree_plunk` is a Spree Commerce extension that connects a Spree store to Plunk for server-side contact sync, consent-safe event tracking, and selected transactional email handoff.

It is built for marketing use cases such as workflows, campaigns, and audience segmentation. Transactional emails still stay with Spree/Rails by default unless an operator explicitly enables the Plunk transactional email master switch and one of the supported email-type switches.

## What This Extension Does

- syncs Spree users and newsletter subscribers into Plunk contacts
- refreshes Plunk contact data when user or address records change
- tracks selected Spree commerce events into Plunk for workflows and segmentation
- keeps marketing consent explicit instead of inferring it from behavioral events
- supports both hosted Plunk and self-hosted Plunk through a configurable base API URL
- can optionally accept contact subscription-state callbacks from Plunk and write them back into Spree
- can optionally send the first supported transactional email types through Plunk's HTTP send API

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
- `spree.checkout.email_entered`
- `spree.cart.added`
- `spree.cart.removed`
- `spree.coupon.entered`
- `spree.coupon.removed`
- `spree.coupon.applied`
- `spree.coupon.denied`
- `spree.checkout.step_viewed`
- `spree.checkout.step_completed`
- `spree.order.completed`
- `spree.order.canceled`
- `spree.shipment.shipped`
- `spree.reimbursement.paid`

These events are intended for:

- workflow triggers
- segmentation
- lifecycle automation
- post-purchase marketing flows

Current storefront event-source boundary:

- cart events are line-item backed so the payload stays item-specific
- checkout events are checkout-service backed so step/email tracking follows real server-side state changes
- coupon events are coupon-handler backed so apply/remove outcomes do not depend on storefront analytics
- the storefront analytics handler is currently unused for the supported event set, which avoids duplicate tracking if Spree later emits overlapping analytics events
- browse-only analytics such as product view, product list view, and product search remain deferred

### Transactional Email Handoff

Transactional email delivery through Plunk is default-off and uses Plunk's HTTP `POST /v1/send` API. It does not use SMTP, so local development can send through hosted Plunk as long as the app can reach Plunk and the sender domain is verified in the Plunk project.

The current direct-send handoff supports:

- Store API password reset emails from `customer.password_reset_requested`
- newsletter double opt-in emails from `newsletter_subscriber.subscription_requested`
- checkout-completion order confirmations from `order.completed`
- explicit admin/order-detail order confirmation resends from `order.resend_confirmation_email`
- order cancellation emails from `order.canceled`
- shipment notifications from `shipment.shipped`
- reimbursement notifications from `reimbursement.reimbursed`

Current ownership boundary:

- `spree_plunk` owns only the explicitly enabled email types above.
- Spree/Rails still owns store owner notifications, payment link emails, invitation emails, reports, webhooks, exports, and any other extension-provided mailers that are not listed above.
- Any email type that is also sent by `spree_emails` can duplicate if both systems are configured to send it. Keep one owner per email type while this handoff is partial.
- Password reset is a good early Plunk owner because the local Spree source emits `customer.password_reset_requested`, but the standard consumer email subscriber set does not include a bundled password reset subscriber.
- Order completion handoff preserves `notify_customer: false` and `confirmation_delivered` guards before enqueueing a Plunk send.
- Reset and verification tokens are sent to Plunk as non-persistent template data.
- Storefront URLs may be local during testing, but the sender email domain must still be verified in Plunk.

See [docs/transactional-email-inventory.md](docs/transactional-email-inventory.md) for the detailed email attribution matrix.

### Admin And Operations

- Spree admin integration form for Plunk credentials and base URL
- connectivity check against the Plunk API
- optional default sender fields for direct transactional sends
- optional public API key storage, intentionally unused by the current server-side MVP
- default-off direct transactional send settings for customer-facing `spree_emails` parity
- optional inbound subscription-state webhook guarded by a bearer token
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
| `Default Sender Email` | No | A mailbox on a Plunk-verified sending domain, such as `hello@shop.example.com` | Used by direct transactional sends. If blank, the extension falls back to the store `mail_from_address`. |
| `Default Sender Name` | No | A display name such as `Example Store` | Used with `Default Sender Email`. If you set this, also set `Default Sender Email` so the stored sender identity is complete. |
| `Enable Plunk Transactional Email` | No | Check this only after the sender domain is verified in Plunk | Master switch for direct `POST /v1/send` delivery. Disabled by default. |
| `Send Password Reset Emails` | No | Check this when Plunk should send Store API password reset emails | Requires `Enable Plunk Transactional Email`. |
| `Password Reset Template ID` | No | A Plunk template ID for password reset email content | If blank, the extension sends a simple inline HTML body. |
| `Send Newsletter Confirmation Emails` | No | Check this when Plunk should send newsletter double opt-in emails | Requires `Enable Plunk Transactional Email`. Avoid enabling a second Spree/Rails owner for the same email. |
| `Newsletter Confirmation Template ID` | No | A Plunk template ID for newsletter confirmation content | If blank, the extension sends a simple inline HTML body. |
| `Send Order Confirmation Emails` | No | Check this when Plunk should send checkout-completion order confirmation emails | Requires `Enable Plunk Transactional Email`. Respects `notify_customer: false` and `confirmation_delivered`. |
| `Send Order Confirmation Resends` | No | Check this when Plunk should send explicit order confirmation resend requests | Requires `Enable Plunk Transactional Email`. Shares the order confirmation template. |
| `Order Confirmation Template ID` | No | A Plunk template ID for order confirmation content | If blank, the extension sends a simple inline HTML body. |
| `Send Order Cancellation Emails` | No | Check this when Plunk should send customer order cancellation emails | Requires `Enable Plunk Transactional Email`. Respects `notify_customer: false`. |
| `Order Cancellation Template ID` | No | A Plunk template ID for order cancellation content | If blank, the extension sends a simple inline HTML body. |
| `Send Shipment Shipped Emails` | No | Check this when Plunk should send shipped shipment notifications | Requires `Enable Plunk Transactional Email`. |
| `Shipment Shipped Template ID` | No | A Plunk template ID for shipment notification content | If blank, the extension sends a simple inline HTML body. |
| `Send Reimbursement Emails` | No | Check this when Plunk should send reimbursement notifications | Requires `Enable Plunk Transactional Email`. |
| `Reimbursement Template ID` | No | A Plunk template ID for reimbursement notification content | If blank, the extension sends a simple inline HTML body. |
| `Enable Subscription Webhook` | No | Check this only if you want Plunk contact subscription changes to write back into Spree | Disabled by default. |
| `Subscription Webhook Authorization Token` | Required only when webhook is enabled | A shared secret that you generate yourself | Plunk will send this back in the `Authorization` header as `Bearer <token>`. |

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

- Direct transactional sends use `Default Sender Email` first and fall back to the store `mail_from_address`.
- Hosted Plunk validates the domain of the `from` email address. Verifying `shop.example.com` allows addresses such as `hello@shop.example.com`, but not `hello@example.com`.
- These fields do not affect contact sync, newsletter sync, or event tracking.
- They are safe to leave blank if transactional email handoff is disabled.

#### Transactional Email Settings

- `Enable Plunk Transactional Email` is the master switch.
- Each supported email type has its own opt-in switch.
- Template IDs are optional. When a template ID is present, Plunk renders the template with the provided `data` payload. When it is blank, the extension sends a simple inline HTML body.
- Password reset payloads include `reset_token` and `reset_url` as non-persistent Plunk data.
- Newsletter confirmation payloads include `verification_token`, `verification_url`, and `confirmation_url` as non-persistent Plunk data.
- Order confirmation and cancellation payloads include order summary data such as order number, totals, item count, completion time, cancellation time, and store URL.
- Shipment payloads include shipment number, order number, tracking, shipping method, stock location, cost, totals, and shipped time.
- Reimbursement payloads include reimbursement number, order number, reimbursement status, amounts, and return item count.
- Localhost storefront URLs are acceptable in test links, but the sender email domain must be verified in Plunk even for local testing.

## Recommended Setup Flow

1. In Plunk, confirm that you have a usable secret API key for the correct workspace.
2. In Spree Admin, set `Plunk Base URL` and `Secret API Key`.
3. Run the built-in connection check from the admin UI.
4. Create or update a newsletter subscriber in Spree and confirm that a Plunk contact is created.
5. Complete a test order and confirm that Plunk receives `spree.order.completed`.
6. Enable the inbound subscription webhook only after the outbound contact sync path is already behaving correctly.

### Transactional Email Setup Flow

1. In Plunk, verify the sender domain you plan to use.
2. In Spree Admin, set `Default Sender Email` to a mailbox on that verified domain, or make sure the store `mail_from_address` already uses one.
3. Enable `Enable Plunk Transactional Email`.
4. Enable exactly the email types that Plunk should own.
5. Add Plunk template IDs if you want Plunk-managed template content; otherwise the extension will send simple inline HTML.
6. Trigger the selected email type, such as password reset, newsletter subscription request, order completion, order cancellation, shipment shipped, reimbursement, or explicit order confirmation resend.
7. Watch Sidekiq and Plunk delivery logs for send failures such as unverified sender domains.

## API Strategy

The current server-side integration intentionally uses:

- `POST /contacts` for contact upsert
- `POST /contacts` with explicit `subscribed: true` for subscribe flows
- `POST /contacts` with explicit `subscribed: false` for unsubscribe flows
- `POST /events/track` for event delivery after the contact has been ensured
- `POST /v1/send` for explicitly enabled direct transactional email handoff

This extension does not rely on `/v1/track` for server-side commerce sync. The reason is important: Plunk documents that `/v1/track` can auto-create a contact, and contacts created that way are subscribed by default. The extension avoids that path so consent stays explicit.

## Consent And Safety Rules

- behavioral activity does not imply marketing consent
- only explicit newsletter opt-in should set `subscribed: true`
- user, checkout, and order-backed contact creation should stay unsubscribed unless consent is known
- commerce events should preserve an existing customer consent state instead of downgrading or upgrading it implicitly
- the subscription webhook is disabled by default
- webhook writeback only accepts explicit contact subscription-state semantics

## Inbound Subscription Webhook

When enabled, the extension can receive a Plunk contact subscription webhook and apply that change locally.

Current behavior:

- requires explicit operator opt-in
- requires an authorization bearer token
- accepts explicit `contact.subscribed` and `contact.unsubscribed` semantics
- looks up the local email in Spree
- creates or verifies the matching newsletter subscriber when Plunk subscribes the contact
- removes the matching newsletter subscriber when Plunk unsubscribes the contact
- updates `accepts_email_marketing` on the matching user when applicable
- suppresses Spree event publication during the local writeback to avoid immediate echo loops
- ignores duplicate deliveries using replay protection
- can create a verified newsletter subscriber for a known email even when only the Plunk-side subscription state exists locally

### How The Webhook Works

The endpoint is:

```text
POST /plunk/webhooks/unsubscribe/:integration_id
```

The request flow is:

1. Spree finds the active Plunk integration by `integration_id`.
2. The webhook must be enabled for that integration or the endpoint returns `404`.
3. Spree checks the `Authorization` header and requires an exact bearer-token match.
4. Spree accepts the request only if the payload clearly indicates contact subscription-state semantics.
5. Spree resolves the contact email and applies the matching local subscribe or unsubscribe writeback.
6. Duplicate deliveries are ignored so the endpoint stays idempotent.

The current webhook processor accepts these signals as proof of contact subscription state:

- `contact.subscribed: true`
- `contact.subscribed: false`
- top-level `subscribed: true`
- top-level `subscribed: false`
- event name `contact.subscribed`
- event name `contact.unsubscribed`

The current implementation prefers the default Plunk webhook payload and extracts the email from:

- `contact.email`
- or top-level `email`

### How To Get The `Subscription Webhook Authorization Token`

This token is not issued by Plunk.

It is a shared secret that you generate yourself and configure in both places:

1. Store it in Spree Admin as `Subscription Webhook Authorization Token`.
2. Send the same value from the Plunk webhook step as:

```text
Authorization: Bearer your-secret-token
```

Example:

- Spree field `Subscription Webhook Authorization Token`:
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

Plunk's own webhook guidance matches the shape this extension expects: use workflow triggers such as `contact.subscribed` and `contact.unsubscribed`, send a public HTTP request, and authenticate it with a shared-secret header.

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
9. Repeat the same setup for a second Plunk workflow triggered by `contact.subscribed` and send it to the same Spree endpoint.

Notes:

- The webhook URL must be publicly reachable from Plunk.
- HTTPS is preferred.
- Plunk webhook delivery is workflow-based, so no workflow means no webhook.
- This extension is built to work with Plunk's default webhook payload shape.
- If you choose a custom webhook body, it still needs to include explicit subscription-state semantics plus the contact email.

### Expected Local Result After A Successful Plunk Subscription Change

If Plunk flips a contact to subscribed and the webhook is configured correctly:

- the matching `Spree::NewsletterSubscriber` row is created or verified
- the matching user's `accepts_email_marketing` becomes `true` when supported
- repeating the same delivery should stay safe and idempotent

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

- automatic removal or disabling of `spree_emails`
- payment link, store owner notification, invitation, report, export, or webhook system emails
- default-enabling Plunk transactional sends without an explicit operator decision per email type
- anonymous visitor tracking
- storefront public-key or browser-side tracking
- back-in-stock workflow parity
- campaign or workflow authoring inside Spree admin
