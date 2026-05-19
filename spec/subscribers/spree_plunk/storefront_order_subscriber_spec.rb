require 'spec_helper'

RSpec.describe SpreePlunk::StorefrontOrderSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }

  before do
    integration
    clear_enqueued_jobs
  end

  it 'runs synchronously so storefront order tracking only needs the Plunk job queue' do
    expect(described_class.subscription_options).to eq(async: false)
  end

  it 'enqueues checkout email tracking from an order payload snapshot' do
    payload = {
      'store_id' => store.id,
      'email' => 'checkout@example.com',
      'order_id' => 'or_123',
      'order_record_id' => 123,
      'checkout_step' => 'address'
    }
    event = Spree::Event.new(name: 'checkout.email_entered', store_id: store.id, payload: payload)

    expect {
      subscriber.send(:handle_order_event, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED,
      nil,
      nil,
      'checkout@example.com',
      payload
    )
  end

  it 'enqueues coupon denied tracking from an order payload snapshot' do
    payload = {
      'store_id' => store.id,
      'email' => 'buyer@example.com',
      'order_id' => 'or_123',
      'coupon_code' => 'save10',
      'coupon_status_code' => 'coupon_code_not_found'
    }
    event = Spree::Event.new(name: 'coupon.denied', store_id: store.id, payload: payload)

    expect {
      subscriber.send(:handle_order_event, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::COUPON_DENIED,
      nil,
      nil,
      'buyer@example.com',
      payload
    )
  end
end
