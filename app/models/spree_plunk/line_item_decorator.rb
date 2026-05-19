module SpreePlunk
  module LineItemDecorator
    def event_payload
      payload = super.stringify_keys
      cart_activity_event = cart_activity_event_name

      payload.merge(snapshot_payload).tap do |merged_payload|
        merged_payload['cart_activity_event'] = cart_activity_event if cart_activity_event.present?
      end
    end

    private

    def capture_pre_destroy_payload
      @_current_event_name = "#{event_prefix}.deleted"
      super
    ensure
      @_current_event_name = nil
    end

    def cart_activity_event_name
      case @_current_event_name
      when "#{event_prefix}.created"
        quantity.to_i.positive? ? 'added' : nil
      when "#{event_prefix}.updated"
        return unless saved_change_to_quantity?

        previous_quantity, current_quantity = saved_change_to_quantity
        return 'added' if current_quantity.to_i > previous_quantity.to_i
        return 'removed' if current_quantity.to_i < previous_quantity.to_i
      when "#{event_prefix}.deleted"
        quantity.to_i.positive? ? 'removed' : nil
      end
    end

    def snapshot_payload
      {
        'user_id' => order&.user_id,
        'store_id' => order&.store_id,
        'store_code' => order&.store&.code,
        'email' => resolved_event_email,
        'line_item_id' => prefixed_id,
        'line_item_record_id' => id,
        'order_id' => order&.prefixed_id,
        'order_record_id' => order&.id,
        'order_number' => order&.number,
        'quantity' => quantity,
        'previous_quantity' => previous_quantity,
        'unit_price' => price.to_f,
        'line_item_total' => amount.to_f,
        'currency' => order&.currency,
        'variant_id' => variant&.prefixed_id,
        'product_id' => product&.prefixed_id,
        'product_name' => name,
        'sku' => sku
      }.compact
    end

    def previous_quantity
      if @_current_event_name == "#{event_prefix}.updated" && saved_change_to_quantity?
        saved_change_to_quantity.first
      elsif @_current_event_name == "#{event_prefix}.deleted"
        quantity
      end
    end

    def resolved_event_email
      order&.email.presence || order&.user&.email.presence
    end
  end
end

::Spree::LineItem.prepend(SpreePlunk::LineItemDecorator)
