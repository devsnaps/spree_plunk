module SpreePlunk
  class PaymentLinkEmailPresenter < OrderTransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Payment link for order ##{order_number}",
        body: body,
        template_id: plunk_integration.preferred_payment_link_template_id,
        data: order_data(email_type: TransactionalEmailTypes::PAYMENT_LINK).merge(
          payment_url: payment_url
        ),
        headers: headers(
          email_type: TransactionalEmailTypes::PAYMENT_LINK,
          resource_type: ::Spree::Order.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def payment_url
      event_value(:payment_url)
    end

    def body
      html_document(
        "Payment link for order ##{order_number}",
        paragraphs: [
          "Use this link to complete payment for your #{store_name} order.",
          "You can ignore this email if the order has already been paid."
        ],
        action_url: payment_url,
        action_label: 'Pay for order'
      )
    end
  end
end
