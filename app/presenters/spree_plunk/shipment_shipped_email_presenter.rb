module SpreePlunk
  class ShipmentShippedEmailPresenter < TransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} order #{order_number} has shipped",
        body: body,
        template_id: plunk_integration.preferred_shipment_shipped_template_id,
        data: shipment_data,
        headers: headers(
          email_type: TransactionalEmailTypes::SHIPMENT_SHIPPED,
          resource_type: ::Spree::Shipment.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def resolved_email
      email.presence || order&.email.presence || order&.user&.email
    end

    def order
      resource&.order
    end

    def order_number
      order&.number
    end

    def shipment_data
      return {} unless resource

      SpreePlunk::ShipmentPresenter.new(shipment: resource, store: store).call.merge(
        email_type: TransactionalEmailTypes::SHIPMENT_SHIPPED,
        store_name: store_name,
        recipient_email: resolved_email
      )
    end

    def body
      paragraphs = ["Your order #{order_number} has shipped."]
      paragraphs << "Tracking: #{resource.tracking}" if resource&.tracking.present?

      html_document(
        "Your #{store_name} order has shipped",
        paragraphs: paragraphs,
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end
  end
end
