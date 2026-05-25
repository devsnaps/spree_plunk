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
      preferred_order_confirmation_resend_email_enabled: order_confirmation_resend_enabled,
      preferred_default_from_email: 'plunk@example.com',
      preferred_default_from_name: 'Example Store'
    )
  end
  let(:transactional_enabled) { true }
  let(:password_reset_enabled) { false }
  let(:newsletter_confirmation_enabled) { false }
  let(:order_confirmation_resend_enabled) { false }
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

  context 'when sending an order confirmation resend' do
    let(:email_type) { SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND }
    let(:order_confirmation_resend_enabled) { true }
    let(:resource) { create(:completed_order_with_totals, store: store, email: 'buyer@example.com', confirmation_delivered: false) }
    let(:email) { resource.email }

    it 'marks the order confirmation as delivered after Plunk accepts the send' do
      expect { result }.to change { resource.reload.confirmation_delivered? }.from(false).to(true)
    end
  end
end
