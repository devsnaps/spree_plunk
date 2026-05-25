# Transactional Email Inventory

Last updated: 2026-05-25

This document tracks the email ownership boundary between Spree/Rails, `spree_emails`, `spree_plunk`, and Plunk. It is intentionally more detailed than the README so implementation work can move email by email without losing attribution.

## Current Rule

- Spree remains the source of truth for orders, shipments, reimbursements, invitations, exports, reports, password reset tokens, newsletter verification tokens, and consent state.
- `spree_plunk` may own a transactional send only when the Spree fact source, recipient, template data, sender domain, idempotency behavior, and fallback behavior are explicit.
- Plunk sends through `POST /v1/send` for direct transactional handoff. Hosted Plunk does not require SMTP for this path.
- Localhost storefront links can be used during local testing, but the `from` email domain must be verified in the Plunk project.
- Do not let two systems send the same email type unless duplicate prevention is built and tested.
- Transactional sends must not subscribe, resubscribe, unsubscribe, or otherwise change marketing consent.
- Order-backed transactional template data is sent as non-persistent Plunk data and includes both structured values and Plunk-template-friendly HTML/text fragments for line items, totals, addresses, and shipments.

## Customer-Facing Email Matrix

| Email or flow | Spree fact source | Current Spree sender | Current `spree_plunk` status | Recommended owner now | Guardrails |
| --- | --- | --- | --- | --- | --- |
| Password reset | `customer.password_reset_requested` from Store API password reset creation | No bundled `spree_emails` subscriber in the current local Spree source; host apps may still have Devise/non-Store-API reset mailers | Implemented through `SpreePlunk::TransactionalEmailSubscriber`, `password_reset` presenter, and `POST /v1/send`; locally verified received after using a verified sender domain | `spree_plunk` for Store API reset requests | Keep reset token and reset URL as non-persistent Plunk data. Keep Spree token generation and redirect URL validation as the authority. |
| Newsletter double opt-in confirmation | `newsletter_subscriber.subscription_requested` | `Spree::NewsletterMailer.email_confirmation` from `spree_emails` when consumer transactional emails are enabled | Implemented through `newsletter_confirmation` direct send, but duplicate risk exists if `spree_emails` is also active for the same store/email type | Choose one owner per store; `spree_plunk` is acceptable when this email type switch is enabled and Spree duplicate sending is controlled | Do not set Plunk `subscribed: true` until Spree verifies the subscriber. Send verification token/URL as non-persistent Plunk data. |
| Manual order confirmation resend | `order.resend_confirmation_email` | `Spree::OrderMailer.confirm_email` from `spree_emails` when consumer transactional emails are enabled | Implemented through `order_confirmation_resend` direct send, but duplicate risk exists if `spree_emails` is also active | Choose one owner per store; `spree_plunk` is a lower-risk receipt handoff because the action is explicit | Shares the order confirmation template and marks `confirmation_delivered` after Plunk accepts the send. |
| Order confirmation on checkout completion | `order.completed` | `Spree::OrderMailer.confirm_email` from `spree_emails`; also may send store owner notification | Implemented through `order_confirmation` direct send, default off; still tracks `spree.order.completed` as a Plunk event | Choose one customer receipt owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | Preserves `notify_customer: false` and `confirmation_delivered`. Store owner notification remains a separate Spree/Rails-owned path. |
| Order cancellation | `order.canceled` | `Spree::OrderMailer.cancel_email` from `spree_emails` | Implemented through `order_cancellation` direct send, default off; still tracks `spree.order.canceled` as a Plunk event | Choose one owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | Respects `notify_customer: false`. |
| Shipment shipped notification | `shipment.shipped` | `Spree::ShipmentMailer.shipped_email` from `spree_emails` when consumer transactional emails are enabled | Implemented through `shipment_shipped` direct send, default off; still tracks `spree.shipment.shipped` as a Plunk event | Choose one owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | Use the Rails event `shipment.shipped`; do not invent a storefront-only shipped event. |
| Reimbursement notification | `reimbursement.reimbursed` | `Spree::ReimbursementMailer.reimbursement_email` from `spree_emails` when consumer transactional emails are enabled | Implemented through `reimbursement` direct send, default off; still tracks `spree.reimbursement.paid` as a Plunk event | Choose one owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | Keep refund/reimbursement wording aligned between the Spree fact source, Plunk event, and customer-facing template. |
| Payment link email | Admin payment link action | `Spree::OrderMailer.payment_link_email` called directly by the admin payment link controller | Implemented through `payment_link` direct send plus a payment-link controller decorator, default off | Choose one owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | This is not a subscriber path. When enabled, the decorator does not call `Spree::OrderMailer.payment_link_email`; when disabled, it preserves the mailer fallback if that mailer exists. |
| Customer registration confirmation or welcome | No confirmed direct transactional event in the current local Spree source | Usually Devise/Confirmable or host-app behavior if enabled | Not covered | Defer until the account confirmation/welcome rule is explicit | Registration alone must not imply marketing consent. |
| Invitation created, accepted, or resent | `invitation.created`, `invitation.accepted`, `invitation.resent` | `Spree::InvitationMailer` from Spree core | Not covered | Keep Spree/Rails first | Not part of `spree_emails`; replacing it needs a core-mailer boundary decision. |

## Admin And System Email Matrix

| Email or flow | Spree fact source | Current Spree sender | Current `spree_plunk` status | Recommended owner now | Guardrails |
| --- | --- | --- | --- | --- | --- |
| Store owner new order notification | Side effect of `order.completed` handling in `Spree::OrderEmailSubscriber` | `Spree::OrderMailer.store_owner_notification_email` from `spree_emails` | Implemented through `store_owner_notification` direct send, default off | Choose one owner per store; `spree_plunk` can own this after `spree_emails` sending is controlled | This is an operator notification, not a customer receipt. It has a separate owner switch and respects `store_owner_notification_delivered`. |
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
| Password reset | `customer.password_reset_requested` | `preferred_transactional_email_enabled` and `preferred_password_reset_email_enabled` | Implemented and locally verified received with a verified sender domain. |
| Newsletter double opt-in confirmation | `newsletter_subscriber.subscription_requested` | `preferred_transactional_email_enabled` and `preferred_newsletter_confirmation_email_enabled` | Implemented; enable only when the Spree/Rails sender for the same email is controlled. |
| Order confirmation | `order.completed` | `preferred_transactional_email_enabled` and `preferred_order_confirmation_email_enabled` | Implemented; preserves `notify_customer: false` and `confirmation_delivered`; includes non-persistent order line item, totals, address, and shipment template data. Enable only when `spree_emails` customer receipt sending is controlled. |
| Manual order confirmation resend | `order.resend_confirmation_email` | `preferred_transactional_email_enabled` and `preferred_order_confirmation_resend_email_enabled` | Implemented; verify the admin/order-detail action path and avoid duplicate sends from `spree_emails`. |
| Order cancellation | `order.canceled` | `preferred_transactional_email_enabled` and `preferred_order_cancellation_email_enabled` | Implemented; preserves `notify_customer: false`; includes non-persistent order line item, totals, address, and shipment template data. Enable only when `spree_emails` cancellation sending is controlled. |
| Shipment shipped notification | `shipment.shipped` | `preferred_transactional_email_enabled` and `preferred_shipment_shipped_email_enabled` | Implemented; enable only when `spree_emails` shipment notification sending is controlled. |
| Reimbursement notification | `reimbursement.reimbursed` | `preferred_transactional_email_enabled` and `preferred_reimbursement_email_enabled` | Implemented; enable only when `spree_emails` reimbursement notification sending is controlled. |
| Store owner new-order notification | `order.completed` | `preferred_transactional_email_enabled` and `preferred_store_owner_notification_email_enabled` | Implemented; preserves `store_owner_notification_delivered`; includes non-persistent order line item, totals, address, shipment, and customer email template data. Enable only when `spree_emails` store owner notification sending is controlled. |
| Payment link email | Admin payment link action | `preferred_transactional_email_enabled` and `preferred_payment_link_email_enabled` | Implemented; payment URL and order template data are sent as non-persistent Plunk data. Enable only when `spree_emails` payment link sending is controlled. |

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
