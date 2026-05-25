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
      expect(payload[:data][:email_type]).to eq(non_persistent_plunk_value(SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT))
      expect(plunk_data_value(payload[:data], :store_name)).to eq('Example Store')
      expect(plunk_data_value(payload[:data], :reimbursement_number)).to eq(reimbursement.number)
      expect(plunk_data_value(payload[:data], :order_number)).to eq(reimbursement.order.number)
      expect(plunk_data_value(payload[:data], :recipient_email)).to eq('buyer@example.com')
      expect(plunk_data_value(payload[:data], :reimbursement_total_display)).to be_present
      expect(plunk_data_value(payload[:data], :return_items)).not_to be_empty
      expect(plunk_data_value(payload[:data], :return_items_html)).to include('<table')
      expect(plunk_data_value(payload[:data], :return_items_text)).to include('x ')
      expect(payload.dig(:headers, 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT)
    end
  end
end
