require 'spec_helper'

RSpec.describe SpreePlunk::StoreOwnerNotificationEmailPresenter do
  it 'builds a Plunk store owner notification payload' do
    store = create(
      :store,
      name: 'Example Store',
      code: 'example-store',
      mail_from_address: 'orders@example.com',
      new_order_notifications_email: 'owner@example.com'
    )
    integration = build(:plunk_integration, store: store, preferred_store_owner_notification_template_id: 'tpl_owner')
    user = create(:user, email: 'buyer@example.com')
    order = create(:completed_order_with_totals, store: store, user: user, email: user.email)

    payload = described_class.new(plunk_integration: integration, resource: order).call

    aggregate_failures do
      expect(payload[:to]).to eq('owner@example.com')
      expect(payload[:template]).to eq('tpl_owner')
      expect(payload[:data]).to include(
        email_type: SpreePlunk::TransactionalEmailTypes::STORE_OWNER_NOTIFICATION,
        store_name: 'Example Store',
        order_number: order.number,
        recipient_email: 'owner@example.com',
        customer_email: 'buyer@example.com'
      )
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::STORE_OWNER_NOTIFICATION)
    end
  end
end
