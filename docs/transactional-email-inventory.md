# Transactional Email Inventory

Last updated: 2026-05-31

This document tracks the email ownership boundary between Spree/Rails, `spree_emails`, `spree_plunk`, and Plunk. It is intentionally more detailed than the README so implementation work can move email by email without losing attribution.

## Current Rule

- Spree remains the source of truth for orders, shipments, reimbursements, invitations, exports, reports, password reset tokens, newsletter verification tokens, and consent state.
- `spree_plunk` may own a transactional send only when the Spree fact source, recipient, template data, sender domain, idempotency behavior, and fallback behavior are explicit.
- Plunk sends through `POST /v1/send` for direct transactional handoff. Hosted Plunk does not require SMTP for this path.
- Localhost storefront links can be used during local testing, but the `from` email domain must be verified in the Plunk project.
- Do not let two systems send the same email type unless duplicate prevention is built and tested.
- Transactional sends must not subscribe, resubscribe, unsubscribe, or otherwise change marketing consent.
- Order, shipment, and reimbursement transactional template data is sent as non-persistent Plunk data and includes both structured values and Plunk-template-friendly HTML/text fragments for line items, totals, addresses, shipments, shipment items, return items, and exchange items.
- Use [`docs/spree-emails-handoff-checklist.md`](spree-emails-handoff-checklist.md) when validating a host app after removing `spree_emails`.
- The 2026-05-31 host-app validation confirmed `spree_emails` absent, all current `spree_plunk` transactional switches enabled, no `ActionMailer` deliveries during trigger probes, and one expected `spree_plunk` send per supported trigger. Full live acceptance still requires checking Plunk delivery logs and the test inbox for one delivery per trigger window.

## Customer-Facing Email Matrix

| Email or flow | Spree fact source | Current Spree sender | Current `spree_plunk` status | Recommended owner now | Guardrails |
| --- | --- | --- | --- | --- | --- |
| Password reset | `customer.password_reset_requested` from Store API password reset creation | No bundled `spree_emails` subscriber in the current local Spree source; host apps may still have Devise/non-Store-API reset mailers | Implemented through `SpreePlunk::TransactionalEmailSubscriber`, `password_reset` presenter, and `POST /v1/send`; locally received through Plunk and trigger-probe verified with `spree_emails` absent | `spree_plunk` for Store API reset requests | Keep reset token and reset URL as non-persistent Plunk data. Keep Spree token generation and redirect URL validation as the authority. |
| Newsletter double opt-in confirmation | `newsletter_subscriber.subscription_requested` | `Spree::NewsletterMailer.email_confirmation` from `spree_emails` when consumer transactional emails are enabled | Implemented and trigger-probe verified through `Spree::Newsletter::Subscribe` with `spree_emails` absent | `spree_plunk` when this email type switch is enabled and Spree duplicate sending is controlled | Do not set Plunk `subscribed: true` until Spree verifies the subscriber. Send verification token/URL as non-persistent Plunk data. |
| Manual order confirmation resend | `order.resend_confirmation_email` | `Spree::OrderMailer.confirm_email` from `spree_emails` when consumer transactional emails are enabled | Implemented and trigger-probe verified with `spree_emails` absent | `spree_plunk` when the resend switch is enabled | Shares the order confirmation template and marks `confirmation_delivered` after Plunk accepts the send. |
| Order confirmation on checkout completion | `order.completed` | `Spree::OrderMailer.confirm_email` from `spree_emails`; also may send store owner notification | Implemented and trigger-probe verified with `spree_emails` absent; still tracks `spree.order.completed` as a Plunk event | `spree_plunk` when the confirmation switch is enabled | Preserves `notify_customer: false` and `confirmation_delivered`. Store owner notification has a separate switch and marker. |
| Order cancellation | `order.canceled` | `Spree::OrderMailer.cancel_email` from `spree_emails` | Implemented and trigger-probe verified through `Spree::Orders::Cancel` with `spree_emails` absent; still tracks `spree.order.canceled` as a Plunk event | `spree_plunk` when the cancellation switch is enabled | Respects `notify_customer: false`. |
| Shipment shipped notification | `shipment.shipped` | `Spree::ShipmentMailer.shipped_email` from `spree_emails` when consumer transactional emails are enabled | Implemented and trigger-probe verified with the model default shipment `event_payload`; still tracks `spree.shipment.shipped` as a Plunk event | `spree_plunk` when the shipment switch is enabled | Use the Rails event `shipment.shipped` with the normal payload; do not invent a storefront-only shipped event or omit the shipment id. |
| Reimbursement notification | `reimbursement.reimbursed` | `Spree::ReimbursementMailer.reimbursement_email` from `spree_emails` when consumer transactional emails are enabled | Implemented and trigger-probe verified with the model default reimbursement `event_payload`; still tracks `spree.reimbursement.paid` as a Plunk event | `spree_plunk` when the reimbursement switch is enabled | Keep refund/reimbursement wording aligned between the Spree fact source, Plunk event, and customer-facing template. Do not omit the reimbursement id from the event payload. |
| Payment link email | Admin payment link action | `Spree::OrderMailer.payment_link_email` called directly by the admin payment link controller | Implemented through `payment_link` direct send plus a payment-link controller decorator; trigger-probe verified with the same job payload shape | `spree_plunk` when the payment-link switch is enabled | This is not a subscriber path. When enabled, the decorator does not call `Spree::OrderMailer.payment_link_email`; when disabled, it preserves the mailer fallback if that mailer exists. |
| Customer registration confirmation or welcome | No confirmed direct transactional event in the current local Spree source | Usually Devise/Confirmable or host-app behavior if enabled | Not covered | Defer until the account confirmation/welcome rule is explicit | Registration alone must not imply marketing consent. |
| Invitation created, accepted, or resent | `invitation.created`, `invitation.accepted`, `invitation.resent` | `Spree::InvitationMailer` from Spree core | Not covered | Keep Spree/Rails first | Not part of `spree_emails`; replacing it needs a core-mailer boundary decision. |

## Admin And System Email Matrix

| Email or flow | Spree fact source | Current Spree sender | Current `spree_plunk` status | Recommended owner now | Guardrails |
| --- | --- | --- | --- | --- | --- |
| Store owner new order notification | Side effect of `order.completed` handling in `Spree::OrderEmailSubscriber` | `Spree::OrderMailer.store_owner_notification_email` from `spree_emails` | Implemented and trigger-probe verified with `spree_emails` absent | `spree_plunk` when the store-owner notification switch is enabled and a store notification email is configured | This is an operator notification, not a customer receipt. It has a separate owner switch and respects `store_owner_notification_delivered`. |
| Export completion | Export generation completion | `Spree::ExportMailer.export_done` from Spree core when the export has a user | Not covered | Keep Spree/Rails first | Admin/system mail. Not part of storefront transactional migration. |
| Report completion | Report generation completion | `Spree::ReportMailer.report_done` from Spree core when the report has a user | Not covered | Keep Spree/Rails first | Admin/system mail. Not part of storefront transactional migration. |
| Webhook endpoint disabled | Webhook endpoint auto-disable path | `Spree::WebhookMailer.endpoint_disabled` from Spree core | Not covered | Keep Spree/Rails first | Operational mail. Do not route through marketing workflows. |

## Marketing And Automation Boundary

| Flow | Fact source | Current `spree_plunk` status | Owner | Guardrails |
| --- | --- | --- | --- | --- |
| Marketing campaigns and newsletters | Plunk contact state mirrored from Spree newsletter consent | Contact sync, unsubscribe writeback, and explicit newsletter consent preservation are covered | Plunk | Only explicit newsletter opt-in should set `subscribed: true`. |
| Post-purchase, winback, abandoned checkout, discount delivery | `spree.*` events emitted by `spree_plunk` | Event tracking is covered for cart, checkout, coupon, order, shipment, and reimbursement events | Plunk workflows | Workflows are suitable for marketing automation, but they should not be the only reliability mechanism for receipts or security mail without duplicate and fallback design. |

## Implemented `spree_plunk` Direct-Send Coverage

| Email type | Event | Setting | Operational status |
| --- | --- | --- | --- |
| Password reset | `customer.password_reset_requested` | `preferred_transactional_email_enabled` and `preferred_password_reset_email_enabled` | Implemented; locally received through Plunk with a verified sender domain; trigger-probe verified with `spree_emails` absent. |
| Newsletter double opt-in confirmation | `newsletter_subscriber.subscription_requested` | `preferred_transactional_email_enabled` and `preferred_newsletter_confirmation_email_enabled` | Implemented; trigger-probe verified through `Spree::Newsletter::Subscribe` with `spree_emails` absent. |
| Order confirmation | `order.completed` | `preferred_transactional_email_enabled` and `preferred_order_confirmation_email_enabled` | Implemented; trigger-probe verified with `spree_emails` absent; preserves `notify_customer: false` and `confirmation_delivered`; includes non-persistent order line item, totals, address, and shipment template data. |
| Manual order confirmation resend | `order.resend_confirmation_email` | `preferred_transactional_email_enabled` and `preferred_order_confirmation_resend_email_enabled` | Implemented; trigger-probe verified with `spree_emails` absent; shares order confirmation template and delivered marker. |
| Order cancellation | `order.canceled` | `preferred_transactional_email_enabled` and `preferred_order_cancellation_email_enabled` | Implemented; trigger-probe verified through `Spree::Orders::Cancel`; preserves `notify_customer: false`; includes non-persistent order line item, totals, address, and shipment template data. |
| Shipment shipped notification | `shipment.shipped` | `preferred_transactional_email_enabled` and `preferred_shipment_shipped_email_enabled` | Implemented; trigger-probe verified with the model default shipment `event_payload`; includes non-persistent shipment item, tracking, tracking URL, cost, and shipment summary template data. |
| Reimbursement notification | `reimbursement.reimbursed` | `preferred_transactional_email_enabled` and `preferred_reimbursement_email_enabled` | Implemented; trigger-probe verified with the model default reimbursement `event_payload`; includes non-persistent refund amount, return item, exchange item, and expedited exchange template data. |
| Store owner new-order notification | `order.completed` | `preferred_transactional_email_enabled` and `preferred_store_owner_notification_email_enabled` | Implemented; trigger-probe verified with `spree_emails` absent; preserves `store_owner_notification_delivered`; includes non-persistent order line item, totals, address, shipment, and customer email template data. |
| Payment link email | Admin payment link action | `preferred_transactional_email_enabled` and `preferred_payment_link_email_enabled` | Implemented; trigger-probe verified with the admin decorator job payload shape; payment URL and order template data are sent as non-persistent Plunk data. |

## Source Files Checked

- `spree/emails/app/subscribers/spree/order_email_subscriber.rb`
- `spree/emails/app/subscribers/spree/newsletter_subscriber_email_subscriber.rb`
- `spree/emails/app/subscribers/spree/shipment_email_subscriber.rb`
- `spree/emails/app/subscribers/spree/reimbursement_email_subscriber.rb`
- `spree/api/app/controllers/spree/api/v3/store/customer/password_resets_controller.rb`
- `spree/admin/app/controllers/spree/admin/orders/payment_links_controller.rb`
- `app/controllers/spree_plunk/payment_links_controller_decorator.rb`
- `spree/core/app/subscribers/spree/invitation_email_subscriber.rb`
- `spree/core/app/models/spree/export.rb`
- `spree/core/app/models/spree/report.rb`
- `spree/core/app/models/spree/webhook_endpoint.rb`
- `app/subscribers/spree_plunk/transactional_email_subscriber.rb`
- `app/services/spree_plunk/send_transactional_email.rb`
- `lib/spree_plunk/transactional_email_types.rb`
