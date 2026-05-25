module SpreePlunk
  class StoreOwnerNotificationEmailPresenter < OrderTransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "New order for #{store_name}",
        body: body,
        template_id: plunk_integration.preferred_store_owner_notification_template_id,
        data: order_data(email_type: TransactionalEmailTypes::STORE_OWNER_NOTIFICATION).merge(
          customer_email: customer_email
        ),
        headers: headers(
          email_type: TransactionalEmailTypes::STORE_OWNER_NOTIFICATION,
          resource_type: ::Spree::Order.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def resolved_email
      email.presence || store&.new_order_notifications_email
    end

    def customer_email
      resource&.email.presence || resource&.user&.email
    end

    def body
      html_document(
        "New order for #{store_name}",
        paragraphs: [
          "A new order #{order_number} has been placed.",
          "Order total: #{display_total}",
          "Customer email: #{customer_email}"
        ],
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end
  end
end
