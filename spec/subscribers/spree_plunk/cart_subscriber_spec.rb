require 'spec_helper'

RSpec.describe SpreePlunk::CartSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }

  before do
    integration
    clear_enqueued_jobs
  end

  it 'runs synchronously so cart tracking only needs the Plunk job queue' do
    expect(described_class.subscription_options).to eq(async: false)
  end

  it 'enqueues cart-added tracking from a line-item payload snapshot' do
    payload = {
      'store_id' => store.id,
      'email' => 'buyer@example.com',
      'cart_activity_event' => 'added',
      'line_item_id' => 'li_123',
      'order_id' => 'or_123',
      'order_number' => 'R123456'
    }
    event = Spree::Event.new(name: 'line_item.created', payload: payload)

    expect {
      subscriber.send(:handle_line_item_event, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::CART_ADDED,
      nil,
      nil,
      'buyer@example.com',
      payload
    )
  end

  it 'enqueues cart-removed tracking from a line-item payload snapshot' do
    payload = {
      'store_id' => store.id,
      'email' => 'buyer@example.com',
      'cart_activity_event' => 'removed',
      'line_item_id' => 'li_123'
    }
    event = Spree::Event.new(name: 'line_item.updated', payload: payload)

    expect {
      subscriber.send(:handle_line_item_event, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::CART_REMOVED,
      nil,
      nil,
      'buyer@example.com',
      payload
    )
  end

  it 'skips cart tracking when the payload does not prove an add/remove action' do
    payload = {
      'store_id' => store.id,
      'email' => 'buyer@example.com',
      'cart_activity_event' => nil
    }
    event = Spree::Event.new(name: 'line_item.updated', payload: payload)

    expect {
      subscriber.send(:handle_line_item_event, event)
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end
end
