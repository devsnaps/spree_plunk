require 'spec_helper'

RSpec.describe SpreePlunk::PaymentLinkEmailPresenter do
  it 'builds a Plunk payment link payload with a non-persistent payment URL' do
    store = create(:store, name: 'Example Store', code: 'example-store', mail_from_address: 'orders@example.com')
    integration = build(:plunk_integration, store: store, preferred_payment_link_template_id: 'tpl_payment')
    user = create(:user, email: 'buyer@example.com')
    order = create(:order_with_line_items, store: store, user: user, email: user.email)
    payment_url = "https://shop.example.com/checkout/#{order.token}/payment"

    payload = described_class.new(
      plunk_integration: integration,
      resource: order,
      event_payload: { 'payment_url' => payment_url }
    ).call

    aggregate_failures do
      expect(payload[:to]).to eq('buyer@example.com')
      expect(payload[:template]).to eq('tpl_payment')
      expect(payload[:data]).to include(
        email_type: SpreePlunk::TransactionalEmailTypes::PAYMENT_LINK,
        store_name: 'Example Store',
        order_number: order.number,
        recipient_email: 'buyer@example.com'
      )
      expect(payload.dig(:data, :payment_url)).to eq(value: payment_url, persistent: false)
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::PAYMENT_LINK)
    end
  end
end
