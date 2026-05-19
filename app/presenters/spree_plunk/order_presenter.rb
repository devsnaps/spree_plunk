module SpreePlunk
  class OrderPresenter
    def initialize(order:, store: nil, email: nil)
      @order = order
      @store = store
      @email = email
    end

    def call
      {
        order_id: order.prefixed_id,
        order_number: order.number,
        store_code: store_code,
        email: resolved_email,
        state: order.state,
        checkout_step: order.state,
        payment_state: order.payment_state,
        shipment_state: order.shipment_state,
        currency: order.currency,
        total: order.total.to_f,
        item_total: order.item_total.to_f,
        shipment_total: order.shipment_total.to_f,
        tax_total: order.tax_total.to_f,
        discount_total: order.promo_total.to_f,
        coupon_code: order.coupon_code,
        item_count: order.item_count,
        line_items_count: order.line_items.size,
        completed_at: iso8601(order.completed_at),
        canceled_at: iso8601(order.canceled_at)
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :order, :store, :email

    def store_code
      store&.code || order.store&.code
    end

    def resolved_email
      email.presence || order.email.presence || order.user&.email
    end

    def iso8601(value)
      value&.iso8601
    end
  end
end
