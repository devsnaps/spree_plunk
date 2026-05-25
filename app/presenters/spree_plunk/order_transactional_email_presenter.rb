module SpreePlunk
  class OrderTransactionalEmailPresenter < TransactionalEmailPresenter
    private

    def resolved_email
      email.presence || resource&.email.presence || resource&.user&.email
    end

    def order_number
      resource&.number
    end

    def order_data(email_type:)
      return {} unless resource

      {
        email_type: email_type,
        store_name: store_name,
        store_code: store&.code,
        recipient_email: resolved_email,
        order_id: resource.prefixed_id,
        order_number: resource.number,
        order_state: resource.state,
        payment_state: resource.payment_state,
        shipment_state: resource.shipment_state,
        order_total: display_total,
        currency: resource.currency,
        item_total: resource.item_total&.to_f,
        shipment_total: resource.shipment_total&.to_f,
        tax_total: resource.tax_total&.to_f,
        discount_total: resource.promo_total&.to_f,
        item_count: resource.item_count,
        line_items_count: resource.line_items.size,
        completed_at: resource.completed_at&.iso8601,
        canceled_at: resource.canceled_at&.iso8601,
        store_url: storefront_url
      }
    end

    def display_total
      return unless resource
      return resource.display_total.to_s if resource.respond_to?(:display_total)

      "#{resource.currency} #{format('%.2f', resource.total.to_f)}"
    end
  end
end
