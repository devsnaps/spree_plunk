module SpreePlunk
  class LineItemPresenter
    def initialize(line_item:, store: nil, email: nil)
      @line_item = line_item
      @store = store
      @email = email
    end

    def call
      {
        line_item_id: line_item_identifier,
        order_id: order_identifier,
        order_number: order_number,
        store_code: store_code,
        email: resolved_email,
        quantity: quantity,
        unit_price: unit_price,
        line_item_total: line_item_total,
        currency: currency,
        variant_id: variant_identifier,
        product_id: product_identifier,
        product_name: product_name,
        sku: sku
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :line_item, :store, :email

    def snapshot?
      line_item.is_a?(Hash)
    end

    def store_code
      return snapshot_value('store_code') if snapshot?

      store&.code || order&.store&.code
    end

    def resolved_email
      email.presence || snapshot_value('email') || order&.email.presence || order&.user&.email
    end

    def order
      return if snapshot?

      @order ||= line_item.order
    end

    def line_item_identifier
      return snapshot_value('line_item_id') if snapshot?

      line_item.respond_to?(:prefixed_id) ? line_item.prefixed_id : line_item.id
    end

    def order_identifier
      return snapshot_value('order_id') if snapshot?

      order.respond_to?(:prefixed_id) ? order.prefixed_id : order.id
    end

    def order_number
      return snapshot_value('order_number') if snapshot?

      order&.number
    end

    def snapshot_value(key)
      return unless snapshot?

      line_item[key] || line_item[key.to_sym]
    end

    def quantity
      return line_item.quantity unless snapshot?

      snapshot_value('quantity')
    end

    def unit_price
      return line_item.price.to_f unless snapshot?

      numeric_snapshot_value('unit_price')
    end

    def line_item_total
      return line_item.amount.to_f unless snapshot?

      numeric_snapshot_value('line_item_total')
    end

    def currency
      return snapshot_value('currency') if snapshot?

      order&.currency
    end

    def variant_identifier
      return snapshot_value('variant_id') if snapshot?

      line_item.variant&.prefixed_id
    end

    def product_identifier
      return snapshot_value('product_id') if snapshot?

      line_item.product&.prefixed_id
    end

    def product_name
      return line_item.name unless snapshot?

      snapshot_value('product_name')
    end

    def sku
      return line_item.sku unless snapshot?

      snapshot_value('sku')
    end

    def numeric_snapshot_value(key)
      value = snapshot_value(key)
      return if value.nil?

      value.to_f
    end
  end
end
