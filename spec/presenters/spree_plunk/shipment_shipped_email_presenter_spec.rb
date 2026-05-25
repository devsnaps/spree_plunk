require 'spec_helper'

RSpec.describe SpreePlunk::ShipmentShippedEmailPresenter do
  it 'builds a Plunk shipment shipped payload' do
    store = create(:store, name: 'Example Store', code: 'example-store', mail_from_address: 'orders@example.com')
    integration = build(:plunk_integration, store: store, preferred_shipment_shipped_template_id: 'tpl_shipped')
    user = create(:user, email: 'buyer@example.com')
    shipment = create(:shipped_order, store: store, user: user, email: user.email).shipments.first
    shipment.update_columns(tracking: 'TRACK123', shipped_at: Time.utc(2026, 5, 25, 8, 0, 0))

    payload = described_class.new(plunk_integration: integration, resource: shipment).call

    aggregate_failures do
      expect(payload[:to]).to eq('buyer@example.com')
      expect(payload[:template]).to eq('tpl_shipped')
      expect(payload[:data]).to include(
        email_type: SpreePlunk::TransactionalEmailTypes::SHIPMENT_SHIPPED,
        store_name: 'Example Store',
        shipment_number: shipment.number,
        tracking: 'TRACK123',
        shipped_at: '2026-05-25T08:00:00Z',
        recipient_email: 'buyer@example.com'
      )
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::SHIPMENT_SHIPPED)
    end
  end
end
