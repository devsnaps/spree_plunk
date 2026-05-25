require 'spec_helper'

RSpec.describe Spree::Integrations::Plunk, type: :model do
  let(:store) { Spree::Store.default }

  describe '.icon_path' do
    it 'exposes an integration card icon for the admin list' do
      expect(described_class.icon_path).to start_with('data:image/png;base64,')
    end
  end

  describe 'validations' do
    it 'normalizes operator-entered preference values before validation' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_base_url: ' https://plunk.example.com/api/ ',
        preferred_plunk_secret_api_key: " sk_test_123 \n",
        preferred_plunk_public_api_key: ' pk_test_123 ',
        preferred_unsubscribe_webhook_authorization_token: ' whsec_test_123 ',
        preferred_default_from_email: ' Marketing@Example.com ',
        preferred_default_from_name: ' Example Store ',
        preferred_password_reset_template_id: ' tpl_password ',
        preferred_newsletter_confirmation_template_id: ' tpl_newsletter ',
        preferred_order_confirmation_template_id: ' tpl_order '
      )

      integration.valid?

      aggregate_failures do
        expect(integration.preferred_plunk_base_url).to eq('https://plunk.example.com/api')
        expect(integration.preferred_plunk_secret_api_key).to eq('sk_test_123')
        expect(integration.preferred_plunk_public_api_key).to eq('pk_test_123')
        expect(integration.preferred_unsubscribe_webhook_authorization_token).to eq('whsec_test_123')
        expect(integration.preferred_default_from_email).to eq('marketing@example.com')
        expect(integration.preferred_default_from_name).to eq('Example Store')
        expect(integration.preferred_password_reset_template_id).to eq('tpl_password')
        expect(integration.preferred_newsletter_confirmation_template_id).to eq('tpl_newsletter')
        expect(integration.preferred_order_confirmation_template_id).to eq('tpl_order')
      end
    end

    it 'rejects a Plunk base URL that points at a specific endpoint path' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_base_url: 'https://plunk.example.com/contacts'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_plunk_base_url]).to include('must be the API base URL, not a specific endpoint path')
    end

    it 'rejects a sender name without a sender email' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_default_from_email: '',
        preferred_default_from_name: 'Example Store'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_default_from_email]).to include('is required when Default Sender Name is set')
    end

    it 'rejects secret API keys that contain whitespace' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_secret_api_key: 'sk test'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_plunk_secret_api_key]).to include('must not contain spaces or line breaks')
    end

    it 'requires a webhook authorization token when the unsubscribe intake is enabled' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_unsubscribe_webhook_enabled: true,
        preferred_unsubscribe_webhook_authorization_token: ''
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_unsubscribe_webhook_authorization_token]).to include("can't be blank")
    end
  end

  describe '#can_connect?' do
    context 'when the local configuration is invalid' do
      it 'fails before making a network request and explains what to fix' do
        integration = build(
          :plunk_integration,
          store: store,
          preferred_plunk_base_url: 'https://plunk.example.com/events/track'
        )

        expect(integration.can_connect?).to be(false)
        expect(a_request(:get, 'https://plunk.example.com/events/track/contacts?limit=1')).not_to have_been_made
        expect(integration.connection_error_message).to eq(
          'Review the highlighted configuration fields: Plunk Base URL must be the API base URL, not a specific endpoint path'
        )
      end
    end

    context 'when Plunk accepts the credentials' do
      it 'returns true and clears any prior connection error message' do
        integration = build(:plunk_integration, store: store)
        integration.connection_error_message = 'old error'

        stub_request(:get, 'https://next-api.useplunk.com/contacts?limit=1')
          .with(headers: { 'Authorization' => "Bearer #{integration.preferred_plunk_secret_api_key}" })
          .to_return(status: 200, body: '{"contacts":[]}', headers: { 'Content-Type' => 'application/json' })

        expect(integration.can_connect?).to be(true)
        expect(integration.connection_error_message).to be_nil
      end
    end

    context 'when the secret API key is rejected' do
      it 'returns a clear operator-facing authentication error' do
        integration = build(:plunk_integration, store: store)

        stub_request(:get, 'https://next-api.useplunk.com/contacts?limit=1')
          .to_return(status: 401, body: '{"error":"Invalid API key"}', headers: { 'Content-Type' => 'application/json' })

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to eq(
          'Plunk rejected the secret API key. Confirm that you pasted a valid secret server key for this workspace and try again.'
        )
      end
    end

    context 'when the API is unreachable' do
      it 'returns network troubleshooting guidance' do
        integration = build(
          :plunk_integration,
          store: store,
          preferred_plunk_base_url: 'https://plunk.internal.example'
        )

        stub_request(:get, 'https://plunk.internal.example/contacts?limit=1').to_timeout

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to eq(
          'Spree timed out while contacting Plunk at https://plunk.internal.example. Check DNS, port, TLS, firewall, and that the self-hosted API is reachable from the app server.'
        )
      end
    end
  end

  describe '#track_event' do
    let(:integration) { build(:plunk_integration, store: store) }
    let(:payload) { { name: SpreePlunk::EventNames::ORDER_COMPLETED, contactId: 'cnt_123' } }

    it 'marks 5xx API failures as retryable' do
      stub_request(:post, 'https://next-api.useplunk.com/events/track')
        .to_return(status: 503, body: '{"error":"temporarily unavailable"}', headers: { 'Content-Type' => 'application/json' })

      result = integration.track_event(payload)

      expect(result).to be_failure
      expect(result.value).to include(
        status: 503,
        error_message: 'temporarily unavailable',
        error_code: 'http_503',
        retryable: true
      )
    end

    it 'marks authentication failures as non-retryable' do
      stub_request(:post, 'https://next-api.useplunk.com/events/track')
        .to_return(status: 401, body: '{"error":"Invalid API key"}', headers: { 'Content-Type' => 'application/json' })

      result = integration.track_event(payload)

      expect(result).to be_failure
      expect(result.value).to include(
        status: 401,
        error_message: 'Invalid API key',
        error_code: 'http_401',
        retryable: false
      )
    end
  end

  describe '#send_transactional_email' do
    let(:integration) { build(:plunk_integration, store: store) }
    let(:payload) do
      {
        to: 'buyer@example.com',
        from: 'orders@example.com',
        subject: 'Order confirmation',
        body: '<p>Thanks</p>'
      }
    end

    it 'posts transactional email payloads to Plunk /v1/send' do
      stub_request(:post, 'https://next-api.useplunk.com/v1/send')
        .with(
          headers: { 'Authorization' => "Bearer #{integration.preferred_plunk_secret_api_key}" },
          body: hash_including('to' => 'buyer@example.com', 'subject' => 'Order confirmation')
        )
        .to_return(status: 200, body: '{"id":"email_123"}', headers: { 'Content-Type' => 'application/json' })

      result = integration.send_transactional_email(payload)

      aggregate_failures do
        expect(result).to be_success
        expect(result.value).to include('id' => 'email_123')
      end
    end

    it 'extracts Plunk API messages from domain verification failures' do
      stub_request(:post, 'https://next-api.useplunk.com/v1/send')
        .to_return(
          status: 403,
          body: '{"code":"INTERNAL_SERVER_ERROR","message":"Domain \"example.com\" is not registered. Please add and verify this domain in your project settings.","statusCode":403}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = integration.send_transactional_email(payload)

      expect(result).to be_failure
      expect(result.value).to include(
        status: 403,
        error_message: 'Domain "example.com" is not registered. Please add and verify this domain in your project settings.',
        error_code: 'http_403',
        retryable: false
      )
    end
  end
end
