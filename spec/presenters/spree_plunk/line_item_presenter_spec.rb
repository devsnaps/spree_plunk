require 'spec_helper'

RSpec.describe SpreePlunk::LineItemPresenter do
  let(:store) { create(:store, code: 'default-store') }

  it 'builds cart event data from a line item' do
    user = create(:user, email: 'buyer@example.com')
    order = create(:order, store: store, user: user, email: user.email)
    product = create(:product, stores: [store])
    line_item = create(:line_item, order: order, product: product, quantity: 2, price: 19.99, currency: 'USD')

    payload = described_class.new(line_item: line_item, store: store).call

    expect(payload).to include(
      line_item_id: line_item.prefixed_id,
      order_id: order.prefixed_id,
      order_number: order.number,
      store_code: 'default-store',
      email: 'buyer@example.com',
      quantity: 2,
      unit_price: 19.99,
      line_item_total: 39.98,
      currency: 'USD',
      variant_id: line_item.variant.prefixed_id,
      product_id: product.prefixed_id,
      product_name: product.name,
      sku: line_item.sku
    )
  end
end
