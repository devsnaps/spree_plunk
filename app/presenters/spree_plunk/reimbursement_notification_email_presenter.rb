module SpreePlunk
  class ReimbursementNotificationEmailPresenter < TransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} reimbursement for order #{order_number}",
        body: body,
        template_id: plunk_integration.preferred_reimbursement_template_id,
        data: reimbursement_data,
        headers: headers(
          email_type: TransactionalEmailTypes::REIMBURSEMENT,
          resource_type: ::Spree::Reimbursement.name,
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

    def reimbursement_data
      return {} unless resource

      non_persistent_data_hash(
        SpreePlunk::ReimbursementPresenter.new(reimbursement: resource, store: store).call.merge(
          email_type: TransactionalEmailTypes::REIMBURSEMENT,
          store_name: store_name,
          recipient_email: resolved_email,
          customer_email: customer_email,
          customer_name: customer_name,
          reimbursement_total_display: reimbursement_total_display,
          paid_amount_display: display_money(numeric_value { resource.paid_amount }),
          unpaid_amount_display: display_money(numeric_value { resource.unpaid_amount }),
          return_items: return_items_data,
          return_items_text: return_items_text,
          return_items_html: return_items_html,
          exchange_items: exchange_items_data,
          exchange_items_count: exchange_items_data.size,
          exchange_items_text: exchange_items_text,
          exchange_items_html: exchange_items_html,
          awaiting_return_items_count: awaiting_return_items.size,
          expedited_exchanges: expedited_exchanges?,
          expedited_exchanges_days_window: expedited_exchanges_days_window,
          order_total: order_display_total,
          order_total_amount: numeric_value { order&.total },
          store_url: storefront_url
        )
      )
    end

    def body
      html_document(
        "Your #{store_name} reimbursement",
        paragraphs: [
          "A reimbursement has been processed for order #{order_number}.",
          "You can contact #{store_name} if you have any questions."
        ],
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

    def reimbursement_total_display
      return resource.display_total.to_s if resource.respond_to?(:display_total)

      display_money(numeric_value { resource.total })
    end

    def return_items_data
      @return_items_data ||= resource.return_items.map do |return_item|
        return_item_data(return_item)
      end.reject { |item| item[:product_name].blank? && item[:sku].blank? && item[:exchange_product_name].blank? }
    end

    def return_item_data(return_item)
      variant = return_item_variant(return_item)
      exchange_variant = return_item.exchange_variant
      line_item = return_item.line_item
      total = numeric_value { return_item.total }

      {
        return_item_id: record_identifier(return_item),
        quantity: numeric_value { return_item.return_quantity }&.to_i,
        reception_status: return_item.reception_status,
        acceptance_status: return_item.acceptance_status,
        total: total,
        total_display: return_item_display_total(return_item, total),
        variant_id: record_identifier(variant),
        product_id: record_identifier(variant&.product),
        product_name: variant&.product&.name || line_item&.name,
        variant_name: variant&.name,
        variant_options_text: variant_options_text(variant),
        sku: variant&.sku || line_item&.sku,
        exchange_requested: return_item.exchange_requested?,
        exchange_variant_id: record_identifier(exchange_variant),
        exchange_product_id: record_identifier(exchange_variant&.product),
        exchange_product_name: exchange_variant&.product&.name,
        exchange_variant_name: exchange_variant&.name,
        exchange_variant_options_text: variant_options_text(exchange_variant),
        exchange_sku: exchange_variant&.sku
      }.reject { |_key, value| plunk_data_blank?(value) }
    end

    def return_item_variant(return_item)
      return_item.variant
    rescue NoMethodError
      nil
    end

    def return_item_display_total(return_item, total)
      return return_item.display_total.to_s if return_item.respond_to?(:display_total)

      display_money(total)
    end

    def return_items_text
      return if return_items_data.empty?

      return_items_data.map do |item|
        [
          item[:sku].present? ? "SKU: #{item[:sku]}" : nil,
          item[:product_name],
          item[:variant_options_text].present? ? "(#{item[:variant_options_text]})" : nil,
          "x #{item[:quantity]}",
          item[:total_display] || item[:total]
        ].compact.join(' ')
      end.join("\n")
    end

    def return_items_html
      return if return_items_data.empty?

      rows = return_items_data.map do |item|
        option_text = item[:variant_options_text].present? ? "<br><small>#{h(item[:variant_options_text])}</small>" : ''
        sku_text = item[:sku].present? ? "<br><small>SKU: #{h(item[:sku])}</small>" : ''

        <<~HTML
          <tr>
            <td style="padding: 8px 0;">
              <strong>#{h(item[:product_name])}</strong>#{option_text}#{sku_text}
            </td>
            <td style="padding: 8px 0; text-align: center;">#{h(item[:quantity])}</td>
            <td style="padding: 8px 0; text-align: right;">#{h(item[:total_display] || item[:total])}</td>
          </tr>
        HTML
      end

      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse;">
          <thead>
            <tr>
              <th align="left" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Returned item</th>
              <th align="center" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Qty</th>
              <th align="right" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Refund</th>
            </tr>
          </thead>
          <tbody>
            #{rows.join("\n")}
          </tbody>
        </table>
      HTML
    end

    def exchange_items_data
      @exchange_items_data ||= return_items_data.select { |item| item[:exchange_requested] }
    end

    def exchange_items_text
      return if exchange_items_data.empty?

      exchange_items_data.map do |item|
        original = item_label(item)
        exchange = item_label(item, prefix: :exchange)

        "#{original} -> #{exchange}"
      end.join("\n")
    end

    def exchange_items_html
      return if exchange_items_data.empty?

      rows = exchange_items_data.map do |item|
        <<~HTML
          <tr>
            <td style="padding: 8px 0;">#{h(item_label(item))}</td>
            <td style="padding: 8px 0;">#{h(item_label(item, prefix: :exchange))}</td>
          </tr>
        HTML
      end

      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse;">
          <thead>
            <tr>
              <th align="left" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Original item</th>
              <th align="left" style="border-bottom: 1px solid #e5e7eb; padding: 8px 0;">Exchange item</th>
            </tr>
          </thead>
          <tbody>
            #{rows.join("\n")}
          </tbody>
        </table>
      HTML
    end

    def item_label(item, prefix: nil)
      sku_key = prefix ? :"#{prefix}_sku" : :sku
      product_name_key = prefix ? :"#{prefix}_product_name" : :product_name
      options_key = prefix ? :"#{prefix}_variant_options_text" : :variant_options_text

      [
        item[sku_key],
        item[product_name_key],
        item[options_key].present? ? "(#{item[options_key]})" : nil
      ].compact.join(' ')
    end

    def awaiting_return_items
      @awaiting_return_items ||= resource.return_items.select { |return_item| return_item.reception_status == 'awaiting' }
    end

    def expedited_exchanges?
      !!::Spree::Config[:expedited_exchanges]
    rescue StandardError
      false
    end

    def expedited_exchanges_days_window
      return unless expedited_exchanges?

      ::Spree::Config[:expedited_exchanges_days_window]
    rescue StandardError
      nil
    end

    def order_display_total
      return unless order
      return order.display_total.to_s if order.respond_to?(:display_total)

      display_money(order.total)
    end

    def variant_options_text(variant)
      return if variant.blank?
      return variant.options_text if variant.respond_to?(:options_text) && variant.options_text.present?

      option_values = variant.option_values if variant.respond_to?(:option_values)
      return if option_values.blank?

      option_values.map { |option_value| option_value.presentation || option_value.name }.join(', ')
    end

    def record_identifier(record)
      return if record.blank?

      record.respond_to?(:prefixed_id) ? record.prefixed_id : record.id
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
