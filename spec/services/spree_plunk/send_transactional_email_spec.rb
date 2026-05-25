require 'spec_helper'

RSpec.describe SpreePlunk::SendTransactionalEmail do
  subject(:result) do
    described_class.call(
      plunk_integration: integration,
      email_type: email_type,
      resource: resource,
      email: email,
      event_payload: event_payload
    )
  end

  let(:store) { create(:store, name: 'Example Store', mail_from_address: 'orders@example.com') }
  let(:integration) do
    create(
      :plunk_integration,
      store: store,
      preferred_transactional_email_enabled: transactional_enabled,
      preferred_password_reset_email_enabled: password_reset_enabled,
      preferred_newsletter_confirmation_email_enabled: newsletter_confirmation_enabled,
      preferred_order_confirmation_email_enabled: order_confirmation_enabled,
      preferred_order_confirmation_resend_email_enabled: order_confirmation_resend_enabled,
      preferred_order_cancellation_email_enabled: order_cancellation_enabled,
      preferred_shipment_shipped_email_enabled: shipment_shipped_enabled,
      preferred_reimbursement_email_enabled: reimbursement_enabled,
      preferred_default_from_email: 'plunk@example.com',
      preferred_default_from_name: 'Example Store'
    )
  end
  let(:transactional_enabled) { true }
  let(:password_reset_enabled) { false }
  let(:newsletter_confirmation_enabled) { false }
  let(:order_confirmation_enabled) { false }
  let(:order_confirmation_resend_enabled) { false }
  let(:order_cancellation_enabled) { false }
  let(:shipment_shipped_enabled) { false }
  let(:reimbursement_enabled) { false }
  let(:email_type) { SpreePlunk::TransactionalEmailTypes::PASSWORD_RESET }
  let(:resource) { nil }
  let(:email) { 'buyer@example.com' }
  let(:event_payload) { {} }

  before do
    stub_request(:post, 'https://next-api.useplunk.com/v1/send')
      .to_return(status: 200, body: '{"id":"email_123"}', headers: { 'Content-Type' => 'application/json' })
  end

  context 'when the handoff is disabled' do
    let(:transactional_enabled) { false }

    it 'does not call Plunk' do
      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'transactional_email_disabled')
      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send')).not_to have_been_made
    end
  end

  context 'when sending a password reset' do
    let(:password_reset_enabled) { true }
    let(:event_payload) do
      {
        'email' => 'buyer@example.com',
        'reset_token' => 'reset-token',
        'redirect_url' => 'https://storefront.example.com/reset?source=account#form'
      }
    end

    it 'sends a direct Plunk email without changing marketing consent' do
      expect(result).to be_success

      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send').with { |request|
        body = JSON.parse(request.body)

        aggregate_failures do
          expect(body['to']).to eq('buyer@example.com')
          expect(body['from']).to eq('name' => 'Example Store', 'email' => 'plunk@example.com')
          expect(body['subject']).to eq('Reset your Example Store password')
          expect(body['subscribed']).to be_nil
          expect(body.dig('data', 'reset_token')).to eq('value' => 'reset-token', 'persistent' => false)
          expect(body.dig('data', 'reset_url')).to eq(
            'value' => 'https://storefront.example.com/reset?source=account&token=reset-token#form',
            'persistent' => false
          )
          expect(body.dig('headers', 'X-Spree-Plunk-Email-Type')).to eq(SpreePlunk::TransactionalEmailTypes::PASSWORD_RESET)
        end

        true
      }).to have_been_made
    end
  end

  context 'when sending from a template' do
    let(:password_reset_enabled) { true }
    let(:event_payload) do
      {
        'email' => 'buyer@example.com',
        'reset_token' => 'reset-token',
        'redirect_url' => 'https://storefront.example.com/reset'
      }
    end

    before do
      integration.update!(preferred_password_reset_template_id: 'tpl_password')
    end

    it 'uses the template id and leaves content ownership to Plunk' do
      expect(result).to be_success

      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send').with { |request|
        body = JSON.parse(request.body)

        expect(body).to include('template' => 'tpl_password')
        expect(body).not_to include('subject')
        expect(body).not_to include('body')
        true
      }).to have_been_made
    end
  end

  context 'when sending an order confirmation from checkout completion' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION }
    let(:order_confirmation_enabled) { true }
    let(:resource) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com', confirmation_delivered: false) }
    let(:email) { resource.email }
    let(:event_payload) { { 'id' => resource.to_param, 'notify_customer' => true } }

    it 'sends the confirmation and marks the order as delivered after Plunk accepts it' do
      expect { result }.to change { resource.reload.confirmation_delivered? }.from(false).to(true)

      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send').with { |request|
        body = JSON.parse(request.body)

        expect(body.dig('data', 'email_type')).to eq(SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION)
        expect(body.dig('data', 'order_number')).to eq(resource.number)
        true
      }).to have_been_made
    end
  end

  context 'when the order confirmation was already delivered' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION }
    let(:order_confirmation_enabled) { true }
    let(:resource) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com', confirmation_delivered: true) }
    let(:email) { resource.email }

    it 'skips the send to preserve Spree confirmation idempotency' do
      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'order_confirmation_already_delivered')
      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send')).not_to have_been_made
    end
  end

  context 'when sending an order confirmation resend' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND }
    let(:order_confirmation_resend_enabled) { true }
    let(:resource) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com', confirmation_delivered: false) }
    let(:email) { resource.email }

    it 'marks the order confirmation as delivered after Plunk accepts the send' do
      expect { result }.to change { resource.reload.confirmation_delivered? }.from(false).to(true)
    end
  end

  context 'when sending an order cancellation' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::ORDER_CANCELLATION }
    let(:order_cancellation_enabled) { true }
    let(:resource) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com') }
    let(:email) { resource.email }
    let(:event_payload) { { 'id' => resource.to_param, 'notify_customer' => false } }

    it 'skips when Spree disabled customer notification for the cancellation' do
      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'notify_customer_disabled')
      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send')).not_to have_been_made
    end
  end

  context 'when sending a shipment shipped notification' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::SHIPMENT_SHIPPED }
    let(:shipment_shipped_enabled) { true }
    let(:user) { create(:user, email: 'buyer@example.com') }
    let(:resource) { create(:shipped_order, store: store, user: user, email: user.email).shipments.first }
    let(:email) { resource.order.email }

    it 'sends shipment data to Plunk' do
      expect(result).to be_success

      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send').with { |request|
        body = JSON.parse(request.body)

        expect(body.dig('data', 'email_type')).to eq(SpreePlunk::TransactionalEmailTypes::SHIPMENT_SHIPPED)
        expect(body.dig('data', 'shipment_number')).to eq(resource.number)
        expect(body.dig('data', 'recipient_email')).to eq('buyer@example.com')
        true
      }).to have_been_made
    end
  end

  context 'when sending a reimbursement notification' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT }
    let(:reimbursement_enabled) { true }
    let(:user) { create(:user, email: 'buyer@example.com') }
    let(:resource) do
      create(:reimbursement).tap do |reimbursement|
        reimbursement.order.update_columns(store_id: store.id, user_id: user.id, email: user.email)
        reimbursement.order.reload
      end
    end
    let(:email) { resource.order.email }

    it 'sends reimbursement data to Plunk' do
      expect(result).to be_success

      expect(a_request(:post, 'https://next-api.useplunk.com/v1/send').with { |request|
        body = JSON.parse(request.body)

        expect(body.dig('data', 'email_type')).to eq(SpreePlunk::TransactionalEmailTypes::REIMBURSEMENT)
        expect(body.dig('data', 'reimbursement_number')).to eq(resource.number)
        expect(body.dig('data', 'recipient_email')).to eq('buyer@example.com')
        true
      }).to have_been_made
    end
  end
end
