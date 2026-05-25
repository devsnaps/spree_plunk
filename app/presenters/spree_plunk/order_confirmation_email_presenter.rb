module SpreePlunk
  class OrderConfirmationEmailPresenter < OrderTransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} order confirmation #{order_number}",
        body: body,
        template_id: plunk_integration.preferred_order_confirmation_template_id,
        data: order_data(email_type: TransactionalEmailTypes::ORDER_CONFIRMATION),
        headers: headers(
          email_type: TransactionalEmailTypes::ORDER_CONFIRMATION,
          resource_type: ::Spree::Order.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def body
      html_document(
        "Your #{store_name} order confirmation",
        paragraphs: [
          "Thank you for your order #{order_number}.",
          "Order total: #{display_total}",
          "You can contact #{store_name} if anything looks wrong."
        ],
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end
  end
end
