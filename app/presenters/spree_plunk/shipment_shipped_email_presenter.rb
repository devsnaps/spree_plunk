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

      non_persistent_data_hash(
        SpreePlunk::ShipmentPresenter.new(shipment: resource, store: store).call.merge(
          email_type: TransactionalEmailTypes::SHIPMENT_SHIPPED,
          store_name: store_name,
          recipient_email: resolved_email,
          customer_email: customer_email,
          customer_name: customer_name,
          tracking_url: tracking_url,
          tracking_link_html: tracking_link_html,
          cost_display: display_money(resource.cost),
          total_display: display_money(resource.total),
          discount_total_display: display_money(resource.promo_total),
          shipment_items_count: shipment_items_data.sum { |item| item[:quantity].to_i },
          shipment_items: shipment_items_data,
          shipment_items_text: shipment_items_text,
          shipment_items_html: shipment_items_html,
          order_total: order_display_total,
          order_total_amount: numeric_value { order&.total },
          store_url: storefront_url
        )
      )
    end

    def body
      paragraphs = ["Your order #{order_number} has shipped."]
      paragraphs << "Tracking: #{resource.tracking}" if resource&.tracking.present?
      paragraphs << "Track your shipment: #{tracking_url}" if tracking_url.present?

      html_document(
        "Your #{store_name} order has shipped",
        paragraphs: paragraphs,
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end

    def customer_email
      order&.email.presence || order&.user&.email
    end

    def customer_name
      name_from_address.presence || name_from_user
    end

    def name_from_address
      address = order&.ship_address || order&.bill_address
      return address.name if address&.respond_to?(:name)

      [address&.firstname, address&.lastname].compact_blank.join(' ')
    end

    def name_from_user
      return unless order&.user
      return order.user.name if order.user.respond_to?(:name)

      [order.user.try(:first_name), order.user.try(:last_name)].compact_blank.join(' ')
    end

    def tracking_url
      @tracking_url ||= resource.respond_to?(:tracking_url) ? resource.tracking_url : nil
    end

    def tracking_link_html
      return if tracking_url.blank?

      %(<a href="#{h(tracking_url)}">#{h(tracking_url)}</a>)
    end

    def shipment_items_data
      @shipment_items_data ||= resource.manifest.map do |manifest_item|
        shipment_item_data(manifest_item)
      end.reject { |item| item[:product_name].blank? && item[:sku].blank? }
    end

    def shipment_item_data(manifest_item)
      line_item = manifest_item.line_item
      variant = manifest_item.variant || line_item&.variant
      quantity = manifest_item.quantity.to_i
      unit_price = numeric_value { line_item&.price }
      line_item_total = unit_price && quantity.positive? ? unit_price * quantity : nil

      SpreePlunk::LineItemPresenter.new(line_item: line_item, store: store, email: resolved_email).call.merge(
        quantity: quantity,
        unit_price: unit_price,
        unit_price_display: display_money(unit_price),
        line_item_total: line_item_total,
        line_item_total_display: display_money(line_item_total),
        variant_options_text: variant_options_text(variant)
      ).reject { |_key, value| plunk_data_blank?(value) }
    end

    def variant_options_text(variant)
      return if variant.blank?
      return variant.options_text if variant.respond_to?(:options_text) && variant.options_text.present?

      option_values = variant.option_values if variant.respond_to?(:option_values)
      return if option_values.blank?

      option_values.map { |option_value| option_value.presentation || option_value.name }.join(', ')
    end

    def shipment_items_text
      return if shipment_items_data.empty?

      shipment_items_data.map do |item|
        [
          item[:sku].present? ? "SKU: #{item[:sku]}" : nil,
          item[:product_name],
          item[:variant_options_text].present? ? "(#{item[:variant_options_text]})" : nil,
          "x #{item[:quantity]}",
          item[:line_item_total_display] || item[:line_item_total]
        ].compact.join(' ')
      end.join("\n")
    end

    def shipment_items_html
      return if shipment_items_data.empty?

      rows = shipment_items_data.map do |item|
        option_text = item[:variant_options_text].present? ? "<br><small>#{h(item[:variant_options_text])}</small>" : ''
        sku_text = item[:sku].present? ? "<br><small>SKU: #{h(item[:sku])}</small>" : ''

        <<~HTML
          <tr>
            <td style="padding: 8px 0;">
              <strong>#{h(item[:product_name])}</strong>#{option_text}#{sku_text}
            </td>
            <td style="padding: 8px 0; text-align: center;">#{h(item[:quantity])}</td>
            <td style="padding: 8px 0; text-align: right;">#{h(item[:line_item_total_display] || item[:line_item_total])}</td>
          </tr>
        HTML
      end

      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse;">
          <thead>
            <tr>
              <th align="left" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Item</th>
              <th align="center" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Qty</th>
              <th align="right" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Total</th>
            </tr>
          </thead>
          <tbody>
            #{rows.join("\n")}
          </tbody>
        </table>
      HTML
    end

    def order_display_total
      return unless order
      return order.display_total.to_s if order.respond_to?(:display_total)

      display_money(order.total)
    end

    def numeric_value
      value = yield
      value&.to_f
    rescue NoMethodError, TypeError
      nil
    end

    def display_money(amount)
      return if amount.nil?

      ::Spree::Money.new(amount, currency: resource.currency).to_s
    rescue StandardError
      "#{resource.currency} #{format('%.2f', amount.to_f)}"
    end
  end
end
