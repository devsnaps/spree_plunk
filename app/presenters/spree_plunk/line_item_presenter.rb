module SpreePlunk
  class LineItemPresenter
    def initialize(line_item:, store: nil, email: nil)
      @line_item = line_item
      @store = store
      @email = email
    end

    def call
      {
        line_item_id: prefixed_identifier(line_item),
        order_id: prefixed_identifier(order),
        order_number: order&.number,
        store_code: store_code,
        email: resolved_email,
        quantity: line_item.quantity,
        unit_price: line_item.price.to_f,
        line_item_total: line_item.amount.to_f,
        currency: order&.currency,
        variant_id: prefixed_identifier(line_item.variant),
        product_id: prefixed_identifier(line_item.product),
        product_name: line_item.name,
        sku: line_item.sku
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :line_item, :store, :email

    def order
      @order ||= line_item.order
    end

    def store_code
      store&.code || order&.store&.code
    end

    def resolved_email
      email.presence || order&.email
    end

    def prefixed_identifier(record)
      return if record.nil?

      record.respond_to?(:prefixed_id) ? record.prefixed_id : record.id
    end
  end
end
