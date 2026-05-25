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

      non_persistent_data_hash(
        email_type: email_type,
        store_name: store_name,
        store_code: store&.code,
        recipient_email: resolved_email,
        customer_email: customer_email,
        customer_name: customer_name,
        customer_first_name: customer_first_name,
        customer_last_name: customer_last_name,
        order_id: resource.prefixed_id,
        order_number: resource.number,
        order_state: resource.state,
        payment_state: resource.payment_state,
        shipment_state: resource.shipment_state,
        order_total: display_total,
        order_total_amount: numeric_value { resource.total },
        currency: resource.currency,
        item_total: resource.item_total&.to_f,
        item_total_display: display_money(resource.item_total),
        shipment_total: resource.shipment_total&.to_f,
        shipment_total_display: display_money(resource.shipment_total),
        tax_total: resource.tax_total&.to_f,
        tax_total_display: display_money(resource.tax_total),
        discount_total: resource.promo_total&.to_f,
        discount_total_display: display_money(resource.promo_total),
        gift_card_total: numeric_value { resource.gift_card_total if resource.respond_to?(:gift_card_total) },
        gift_card_total_display: resource.respond_to?(:gift_card_total) ? display_money(resource.gift_card_total) : nil,
        item_count: resource.item_count,
        line_items_count: resource.line_items.size,
        line_items: line_items_data,
        line_items_text: line_items_text,
        line_items_html: line_items_html,
        totals: totals_data,
        totals_text: totals_text,
        totals_html: totals_html,
        shipments: shipments_data,
        shipments_text: shipments_text,
        shipments_html: shipments_html,
        billing_address: address_data(resource.bill_address),
        billing_address_text: address_text(resource.bill_address),
        shipping_address: address_data(resource.ship_address),
        shipping_address_text: address_text(resource.ship_address),
        completed_at: resource.completed_at&.iso8601,
        canceled_at: resource.canceled_at&.iso8601,
        store_url: storefront_url
      )
    end

    def display_total
      return unless resource
      return resource.display_total.to_s if resource.respond_to?(:display_total)

      "#{resource.currency} #{format('%.2f', resource.total.to_f)}"
    end

    def customer_email
      resource&.email.presence || resource&.user&.email
    end

    def customer_name
      name_from_address.presence || name_from_user
    end

    def customer_first_name
      resource&.ship_address&.firstname.presence ||
        resource&.bill_address&.firstname.presence ||
        resource&.user&.try(:first_name)
    end

    def customer_last_name
      resource&.ship_address&.lastname.presence ||
        resource&.bill_address&.lastname.presence ||
        resource&.user&.try(:last_name)
    end

    def name_from_address
      address = resource&.ship_address || resource&.bill_address
      return address.name if address&.respond_to?(:name)

      [address&.firstname, address&.lastname].compact_blank.join(' ')
    end

    def name_from_user
      return unless resource&.user
      return resource.user.name if resource.user.respond_to?(:name)

      [resource.user.try(:first_name), resource.user.try(:last_name)].compact_blank.join(' ')
    end

    def line_items_data
      @line_items_data ||= resource.line_items.map do |line_item|
        line_item_data(line_item)
      end
    end

    def line_item_data(line_item)
      SpreePlunk::LineItemPresenter.new(line_item: line_item, store: store, email: resolved_email).call.merge(
        unit_price_display: display_money(line_item.price),
        line_item_total_display: display_money(line_item.amount),
        variant_options_text: variant_options_text(line_item)
      ).reject { |_key, value| plunk_data_blank?(value) }
    end

    def variant_options_text(line_item)
      option_values = line_item.variant&.option_values
      return if option_values.blank?

      option_values.map { |option_value| option_value.presentation || option_value.name }.join(', ')
    end

    def line_items_text
      return if line_items_data.empty?

      line_items_data.map do |line_item|
        [
          line_item[:product_name],
          "x #{line_item[:quantity]}",
          line_item[:line_item_total_display] || line_item[:line_item_total]
        ].compact.join(' ')
      end.join("\n")
    end

    def line_items_html
      return if line_items_data.empty?

      rows = line_items_data.map do |line_item|
        option_text = line_item[:variant_options_text].present? ? "<br><small>#{h(line_item[:variant_options_text])}</small>" : ''
        <<~HTML
          <tr>
            <td style="padding: 8px 0;">
              <strong>#{h(line_item[:product_name])}</strong>#{option_text}
              #{line_item[:sku].present? ? "<br><small>SKU: #{h(line_item[:sku])}</small>" : ''}
            </td>
            <td style="padding: 8px 0; text-align: center;">#{h(line_item[:quantity])}</td>
            <td style="padding: 8px 0; text-align: right;">#{h(line_item[:line_item_total_display] || line_item[:line_item_total])}</td>
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

    def totals_data
      @totals_data ||= [
        total_row('Subtotal', resource.item_total),
        total_row('Shipping', resource.shipment_total),
        total_row('Tax', resource.tax_total),
        total_row('Discount', resource.promo_total),
        gift_card_total_row,
        total_row('Total', resource.total, display_total)
      ].compact.reject { |row| row[:amount].to_f.zero? && row[:label] != 'Total' }
    end

    def total_row(label, amount, display_amount = nil)
      return if amount.nil?

      {
        label: label,
        amount: amount.to_f,
        display_amount: display_amount.presence || display_money(amount)
      }
    end

    def gift_card_total_row
      return unless resource.respond_to?(:gift_card_total)

      total_row('Gift card', resource.gift_card_total)
    end

    def totals_text
      totals_data.map { |row| "#{row[:label]}: #{row[:display_amount]}" }.join("\n")
    end

    def totals_html
      rows = totals_data.map do |row|
        <<~HTML
          <tr>
            <td style="padding: 4px 0;">#{h(row[:label])}</td>
            <td style="padding: 4px 0; text-align: right;">#{h(row[:display_amount])}</td>
          </tr>
        HTML
      end

      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse;">
          <tbody>
            #{rows.join("\n")}
          </tbody>
        </table>
      HTML
    end

    def shipments_data
      @shipments_data ||= resource.shipments.map do |shipment|
        SpreePlunk::ShipmentPresenter.new(shipment: shipment, store: store).call.merge(
          tracking_url: shipment.respond_to?(:tracking_url) ? shipment.tracking_url : nil,
          cost_display: display_money(shipment.cost),
          total_display: display_money(shipment.total)
        ).reject { |_key, value| plunk_data_blank?(value) }
      end
    end

    def shipments_text
      return if shipments_data.empty?

      shipments_data.map do |shipment|
        [
          shipment[:shipment_number],
          shipment[:shipping_method],
          shipment[:tracking].present? ? "Tracking: #{shipment[:tracking]}" : nil
        ].compact.join(' - ')
      end.join("\n")
    end

    def shipments_html
      return if shipments_data.empty?

      items = shipments_data.map do |shipment|
        details = [
          shipment[:shipping_method],
          shipment[:tracking].present? ? "Tracking: #{shipment[:tracking]}" : nil,
          shipment[:tracking_url]
        ].compact.map { |value| h(value) }.join('<br>')

        "<li><strong>#{h(shipment[:shipment_number])}</strong><br>#{details}</li>"
      end

      "<ul>#{items.join}</ul>"
    end

    def address_data(address)
      return {} unless address

      {
        name: address.respond_to?(:name) ? address.name : [address.firstname, address.lastname].compact_blank.join(' '),
        firstname: address.firstname,
        lastname: address.lastname,
        address1: address.address1,
        address2: address.address2,
        city: address.city,
        zipcode: address.zipcode,
        state_name: address_state_name(address),
        country_name: address_country_name(address),
        phone: address.phone
      }.reject { |_key, value| plunk_data_blank?(value) }
    end

    def address_text(address)
      data = address_data(address)
      return if data.empty?

      [
        data[:name],
        data[:address1],
        data[:address2],
        [data[:city], data[:state_name], data[:zipcode]].compact_blank.join(', '),
        data[:country_name],
        data[:phone].present? ? "Phone: #{data[:phone]}" : nil
      ].compact_blank.join("\n")
    end

    def address_state_name(address)
      address.state&.name.presence || address.state_name
    end

    def address_country_name(address)
      address.country&.name
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
