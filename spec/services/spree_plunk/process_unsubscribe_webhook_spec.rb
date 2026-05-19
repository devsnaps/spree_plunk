require 'spec_helper'

RSpec.describe SpreePlunk::ProcessUnsubscribeWebhook do
  let(:store) { Spree::Store.default }
  let(:integration) do
    create(
      :plunk_integration,
      store: store,
      preferred_unsubscribe_webhook_enabled: true,
      preferred_unsubscribe_webhook_authorization_token: 'whsec_test'
    )
  end

  before do
    clear_enqueued_jobs
    clear_performed_jobs
    Rails.cache.clear
    described_class.replay_cache_store.clear
  end

  it 'delegates unsubscribe application through the local service' do
    expect(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .with(email: 'newsletter@example.com')
      .and_return(Spree::ServiceModule::Result.new(true, { unsubscribed: true }))

    result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'newsletter@example.com', subscribed: false } }
    )

    expect(result).to be_success
  end

  it 'delegates subscribe application through the local service' do
    expect(SpreePlunk::ApplyLocalSubscribe).to receive(:call)
      .with(email: 'newsletter@example.com')
      .and_return(Spree::ServiceModule::Result.new(true, { subscribed: true }))

    result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'newsletter@example.com', subscribed: true } }
    )

    expect(result).to be_success
  end

  it 'accepts a custom event-name payload when it explicitly identifies contact.unsubscribed' do
    allow(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .and_return(Spree::ServiceModule::Result.new(true, { unsubscribed: true }))

    result = described_class.call(
      plunk_integration: integration,
      payload: {
        email: 'newsletter@example.com',
        event_name: 'contact.unsubscribed'
      }
    )

    aggregate_failures do
      expect(result).to be_success
      expect(SpreePlunk::ApplyLocalUnsubscribe).to have_received(:call).with(email: 'newsletter@example.com')
    end
  end

  it 'accepts a custom event-name payload when it explicitly identifies contact.subscribed' do
    allow(SpreePlunk::ApplyLocalSubscribe).to receive(:call)
      .and_return(Spree::ServiceModule::Result.new(true, { subscribed: true }))

    result = described_class.call(
      plunk_integration: integration,
      payload: {
        email: 'newsletter@example.com',
        event_name: 'contact.subscribed'
      }
    )

    aggregate_failures do
      expect(result).to be_success
      expect(SpreePlunk::ApplyLocalSubscribe).to have_received(:call).with(email: 'newsletter@example.com')
    end
  end

  it 'no-ops when the payload does not prove contact subscription semantics' do
    result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'newsletter@example.com' }, event_name: 'workflow.completed' }
    )

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'unsupported_payload')
    end
  end

  it 'passes through local no-op results when no local record matches the webhook email' do
    allow(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .and_return(Spree::ServiceModule::Result.new(true, { skipped: true, reason: 'local_email_not_found' }))

    result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'missing@example.com', subscribed: false } }
    )

    expect(result.value).to include(skipped: true, reason: 'local_email_not_found')
  end

  it 'no-ops when the integration keeps the intake disabled' do
    integration.update!(
      preferred_unsubscribe_webhook_enabled: false,
      preferred_unsubscribe_webhook_authorization_token: nil
    )

    result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'newsletter@example.com', subscribed: false } }
    )

    expect(result.value).to include(skipped: true, reason: 'webhook_disabled')
  end

  it 'suppresses duplicate deliveries that reuse the same execution id' do
    allow(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .and_return(Spree::ServiceModule::Result.new(true, { unsubscribed: true }))

    payload = {
      contact: { email: 'newsletter@example.com', subscribed: false },
      execution: { id: 'exec_123' }
    }

    first_result = described_class.call(plunk_integration: integration, payload: payload)
    second_result = described_class.call(plunk_integration: integration, payload: payload)

    aggregate_failures do
      expect(first_result).to be_success
      expect(second_result.value).to include(skipped: true, reason: 'duplicate_delivery')
      expect(SpreePlunk::ApplyLocalUnsubscribe).to have_received(:call).once
    end
  end

  it 'falls back to a payload digest when the webhook does not include an execution id' do
    allow(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .and_return(Spree::ServiceModule::Result.new(true, { unsubscribed: true }))

    first_result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { email: 'newsletter@example.com', subscribed: false } }
    )
    second_result = described_class.call(
      plunk_integration: integration,
      payload: { contact: { subscribed: false, email: 'newsletter@example.com' } }
    )

    aggregate_failures do
      expect(first_result).to be_success
      expect(second_result.value).to include(skipped: true, reason: 'duplicate_delivery')
      expect(SpreePlunk::ApplyLocalUnsubscribe).to have_received(:call).once
    end
  end

  it 'releases the replay claim when local unsubscribe processing fails' do
    payload = {
      contact: { email: 'newsletter@example.com', subscribed: false },
      execution: { id: 'exec_retryable' }
    }
    failure_result = Spree::ServiceModule::Result.new(false, { reason: 'persistence_error' }, 'failed')

    allow(SpreePlunk::ApplyLocalUnsubscribe).to receive(:call)
      .and_return(failure_result, Spree::ServiceModule::Result.new(true, { unsubscribed: true }))

    first_result = described_class.call(plunk_integration: integration, payload: payload)
    second_result = described_class.call(plunk_integration: integration, payload: payload)

    aggregate_failures do
      expect(first_result).to be_failure
      expect(second_result).to be_success
      expect(SpreePlunk::ApplyLocalUnsubscribe).to have_received(:call).twice
    end
  end
end
