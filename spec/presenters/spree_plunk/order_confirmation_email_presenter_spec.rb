require 'spec_helper'

RSpec.describe SpreePlunk::OrderConfirmationEmailPresenter do
  it 'builds a Plunk order confirmation payload' do
    store = create(:store, name: 'Example Store', code: 'example-store', mail_from_address: 'orders@example.com')
    integration = build(:plunk_integration, store: store, preferred_order_confirmation_template_id: 'tpl_order')
    user = create(:user, email: 'buyer@example.com')
    order = create(:completed_order_with_totals, store: store, user: user, email: user.email)

    payload = described_class.new(plunk_integration: integration, resource: order).call

    aggregate_failures do
      expect(payload[:to]).to eq('buyer@example.com')
      expect(payload[:template]).to eq('tpl_order')
      expect(payload[:data]).to include(
        email_type: SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION,
        store_name: 'Example Store',
        store_code: 'example-store',
        order_number: order.number,
        recipient_email: 'buyer@example.com'
      )
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION)
    end
  end
end
