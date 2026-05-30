# Plunk Email Templates

These templates are ready to paste into Plunk's template editor.

Use the `HTML` editor tab in Plunk. The templates include full HTML, table-based email layout, inline styles, and a small responsive style block. They follow the store's restrained black-and-white visual language: neutral background, thin borders, uppercase labels, compact typography, and black primary actions.

## How To Use

1. Create a template in Plunk.
2. Choose the correct template type:
   - files under `transactional/` must use `Transactional`
   - files under `marketing/` must use `Marketing`
3. Fill in the name, description, subject, from email, and from name from the table below.
4. Paste the HTML file content into the `HTML` tab.
5. Save the template and copy its Plunk template ID into the matching Spree Admin field.

Use a verified sender domain, for example `hello@store.example.com`.

## Transactional Templates

| Spree Admin field | Plunk template type | Suggested template name | Suggested subject line | HTML file |
| --- | --- | --- | --- | --- |
| Password Reset Template ID | Transactional | Spree Password Reset | `Reset your {{store_name ?? Shop}} password` | `transactional/password-reset.html` |
| Newsletter Confirmation Template ID | Transactional | Spree Newsletter Confirmation | `Confirm your {{store_name ?? Shop}} newsletter subscription` | `transactional/newsletter-confirmation.html` |
| Order Confirmation Template ID | Transactional | Spree Order Confirmation | `Your {{store_name ?? Shop}} order {{order_number}} confirmation` | `transactional/order-confirmation.html` |
| Order Cancellation Template ID | Transactional | Spree Order Cancellation | `Your {{store_name ?? Shop}} order {{order_number}} was canceled` | `transactional/order-cancellation.html` |
| Shipment Shipped Template ID | Transactional | Spree Shipment Shipped | `Your {{store_name ?? Shop}} order {{order_number}} has shipped` | `transactional/shipment-shipped.html` |
| Reimbursement Template ID | Transactional | Spree Reimbursement | `Your {{store_name ?? Shop}} reimbursement for {{order_number}}` | `transactional/reimbursement.html` |
| Store Owner Notification Template ID | Transactional | Spree Store Owner Notification | `New order {{order_number}} for {{store_name ?? Shop}}` | `transactional/store-owner-notification.html` |
| Payment Link Template ID | Transactional | Spree Payment Link | `Payment link for {{store_name ?? Shop}} order {{order_number}}` | `transactional/payment-link.html` |

Order confirmation resend uses the same `Order Confirmation Template ID`.

## Marketing Templates

| Use | Plunk template type | Suggested template name | Suggested subject line | HTML file |
| --- | --- | --- | --- | --- |
| Campaigns, newsletters, winback, post-purchase marketing | Marketing | Store Campaign | `New arrivals from {{store_name ?? Shop}}` | `marketing/store-campaign.html` |

Marketing templates should rely on Plunk's marketing footer/unsubscribe behavior. Do not use marketing templates for password reset, order receipt, payment, shipment, or refund emails.

## Variable Notes

Plunk supports `{{variable}}` and `{{variable ?? fallback}}`.

`spree_plunk` pre-renders table fragments for values Plunk cannot loop over:

- `{{line_items_html}}`
- `{{totals_html}}`
- `{{shipments_html}}`
- `{{shipment_items_html}}`
- `{{return_items_html}}`
- `{{exchange_items_html}}`

Those variables are intentionally inserted directly into the template body.
