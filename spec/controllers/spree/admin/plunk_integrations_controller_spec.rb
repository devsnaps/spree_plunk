require 'spec_helper'

RSpec.describe Spree::Admin::IntegrationsController, type: :controller do
  render_views
  stub_authorization!

  let(:store) { Spree::Store.default }
  let!(:integration) { create(:plunk_integration, store: store) }

  before do
    allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
  end

  describe 'GET #index' do
    it 'renders the Plunk integration card metadata for the admin catalog' do
      integration.destroy!

      get :index

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          'Sync Spree customers and newsletter subscribers to Plunk, and send consent-safe commerce events for workflows and segmentation.'
        )
        expect(response.body).to include('data:image/png;base64,')
        expect(response.body).to include('Connect Plunk')
      end
    end
  end

  describe 'GET #new' do
    it 'renders the webhook guidance without requiring a persisted integration id' do
      integration.destroy!

      get :new, params: { integration: { type: Spree::Integrations::Plunk.to_s } }

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        expect(response.body).to include('Inbound subscription-state webhook')
        expect(response.body).to include('after you save this connection')
        expect(response.body.scan('data-controller="password-visibility"').size).to eq(2)
        expect(response.body.scan('data-password-visibility-target="input"').size).to eq(2)
      end
    end
  end

  describe 'GET #edit' do
    it 'renders operator-facing guidance for the Plunk configuration form' do
      get :edit, params: { id: integration.to_param }

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Server-side Plunk sync only needs the secret API key and API base URL.')
        expect(response.body).to include('Do not paste a specific endpoint like')
        expect(response.body).to include('Optional sender defaults')
        expect(response.body).to include('The Public API Key is optional and intentionally unused by the current server-side MVP.')
        expect(response.body).to include('Inbound subscription-state webhook')
        expect(response.body).to include('contact.subscribed')
        expect(response.body).to include('contact.unsubscribed')
        expect(response.body).to include('/plunk/webhooks/unsubscribe/')
      end
    end
  end

  describe 'PUT #update' do
    it 'renders the translated connection failure message returned by the integration' do
      allow_any_instance_of(Spree::Integrations::Plunk).to receive(:can_connect?) do |plunk_integration|
        plunk_integration.connection_error_message = 'Plunk rejected the secret API key.'
        false
      end

      put :update, params: {
        id: integration.to_param,
        integration: {
          preferred_plunk_base_url: integration.preferred_plunk_base_url,
          preferred_plunk_secret_api_key: 'bad-key'
        }
      }

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Unable to connect to Plunk: Plunk rejected the secret API key.')
      end
    end
  end
end
