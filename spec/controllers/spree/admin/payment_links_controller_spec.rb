require 'spec_helper'

RSpec.describe Spree::Admin::Orders::PaymentLinksController, type: :controller do
  include ActiveJob::TestHelper

  stub_authorization!
  render_views

  let(:store) { create(:store, url: 'shop.example.com') }
  let(:user) { create(:user, email: 'buyer@example.com') }
  let(:order) { create(:order_with_line_items, store: store, user: user, email: user.email, state: 'payment') }
  let(:payment_url) { "https://shop.example.com/checkout/#{order.token}/payment" }
  let!(:integration) do
    create(
      :plunk_integration,
      store: store,
      preferred_transactional_email_enabled: true,
      preferred_payment_link_email_enabled: true
    )
  end

  before do
    allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
    allow(Spree::Core::Engine).to receive(:frontend_available?).and_return(true)
    allow(spree).to receive(:checkout_state_url).and_return(payment_url)
    clear_enqueued_jobs
  end

  describe 'POST #create' do
    it 'enqueues a Plunk payment link send when the handoff is enabled' do
      post :create, params: { order_id: order.to_param }

      expect(SpreePlunk::SendTransactionalEmailJob).to have_been_enqueued.with(
        integration.id,
        SpreePlunk::TransactionalEmailTypes::PAYMENT_LINK,
        Spree::Order.name,
        order.id,
        'buyer@example.com',
        { 'payment_url' => payment_url }
      )
      expect(flash[:success]).to eq(Spree.t('admin.orders.payment_link_sent'))
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end

    it 'does not call the Spree mailer when Plunk owns payment links' do
      expect(Spree::OrderMailer).not_to receive(:payment_link_email) if defined?(Spree::OrderMailer)

      post :create, params: { order_id: order.to_param }
    end
  end
end
