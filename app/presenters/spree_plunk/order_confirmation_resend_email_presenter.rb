module SpreePlunk
  class OrderConfirmationResendEmailPresenter < TransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} order confirmation #{order_number}",
        body: body,
        template_id: plunk_integration.preferred_order_confirmation_template_id,
        data: order_data,
        headers: headers(
          email_type: TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND,
          resource_type: ::Spree::Order.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def resolved_email
      email.presence || resource&.email.presence || resource&.user&.email
    end

    def order_number
      resource&.number
    end

    def order_data
      return {} unless resource

      {
        email_type: TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND,
        store_name: store_name,
        store_code: store&.code,
        recipient_email: resolved_email,
        order_id: resource.prefixed_id,
        order_number: resource.number,
        order_total: display_total,
        currency: resource.currency,
        item_total: resource.item_total&.to_f,
        shipment_total: resource.shipment_total&.to_f,
        tax_total: resource.tax_total&.to_f,
        discount_total: resource.promo_total&.to_f,
        item_count: resource.item_count,
        line_items_count: resource.line_items.size,
        completed_at: resource.completed_at&.iso8601,
        store_url: storefront_url
      }
    end

    def body
      html_document(
        "Your #{store_name} order confirmation",
        paragraphs: [
          "Here is another copy of your order confirmation for #{order_number}.",
          "Order total: #{display_total}",
          "You can contact #{store_name} if anything looks wrong."
        ],
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end

    def display_total
      return unless resource
      return resource.display_total.to_s if resource.respond_to?(:display_total)

      "#{resource.currency} #{format('%.2f', resource.total.to_f)}"
    end
  end
end
