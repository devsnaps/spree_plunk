require 'spec_helper'

RSpec.describe SpreePlunk::ReimbursementNotificationEmailPresenter do
  it 'builds a Plunk reimbursement payload' do
    store = create(:store, name: 'Example Store', code: 'example-store', mail_from_address: 'orders@example.com')
    integration = build(:plunk_integration, store: store, preferred_reimbursement_template_id: 'tpl_reimbursement')
    user = create(:user, email: 'buyer@example.com')
    reimbursement = create(:reimbursement)
    reimbursement.order.update_columns(store_id: store.id, user_id: user.id, email: user.email)
    reimbursement.order.reload

    payload = described_class.new(plunk_integration: integration, resource: reimbursement).call

    aggregate_failures do
      expect(payload[:to]).to eq('buyer@example.com')
      expect(payload[:template]).to eq('tpl_reimbursement')
      expect(payload[:data]).to include(
        email_type: SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT,
        store_name: 'Example Store',
        reimbursement_number: reimbursement.number,
        order_number: reimbursement.order.number,
        recipient_email: 'buyer@example.com'
      )
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT)
    end
  end
end
