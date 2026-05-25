module SpreePlunk
  class OrderCancellationEmailPresenter < OrderTransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} order #{order_number} was canceled",
        body: body,
        template_id: plunk_integration.preferred_order_cancellation_template_id,
        data: order_data(email_type: TransactionalEmailTypes::ORDER_CANCELLATION),
        headers: headers(
          email_type: TransactionalEmailTypes::ORDER_CANCELLATION,
          resource_type: ::Spree::Order.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def body
      html_document(
        "Your #{store_name} order was canceled",
        paragraphs: [
          "Your order #{order_number} has been canceled.",
          "You can contact #{store_name} if you have any questions."
        ],
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end
  end
end
