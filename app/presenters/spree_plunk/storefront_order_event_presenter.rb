module SpreePlunk
  class StorefrontOrderEventPresenter
    def initialize(payload:, store: nil, email: nil)
      @payload = payload
      @store = store
      @email = email
    end

    def call
      {
        order_id: value('order_id'),
        order_number: value('order_number'),
        store_code: value('store_code') || store&.code,
        email: resolved_email,
        state: value('state'),
        checkout_step: value('checkout_step') || value('current_checkout_step'),
        previous_checkout_step: value('previous_checkout_step'),
        current_checkout_step: value('current_checkout_step'),
        payment_state: value('payment_state'),
        shipment_state: value('shipment_state'),
        currency: value('currency'),
        total: numeric_value('total'),
        item_total: numeric_value('item_total'),
        shipment_total: numeric_value('shipment_total'),
        tax_total: numeric_value('tax_total'),
        discount_total: numeric_value('discount_total'),
        item_count: value('item_count'),
        line_items_count: value('line_items_count'),
        coupon_code: value('coupon_code'),
        coupon_status_code: value('coupon_status_code'),
        coupon_error: value('coupon_error')
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :payload, :store, :email

    def value(key)
      payload[key] || payload[key.to_sym]
    end

    def numeric_value(key)
      value = value(key)
      return if value.nil?

      value.to_f
    end

    def resolved_email
      email.presence || value('email')
    end
  end
end
