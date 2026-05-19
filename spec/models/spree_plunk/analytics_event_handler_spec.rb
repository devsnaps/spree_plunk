require 'spec_helper'

RSpec.describe SpreePlunk::AnalyticsEventHandler do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:user) { create(:user, email: 'user@example.com') }
  let(:order) { create(:order, user: user, store: store, email: 'order@example.com') }
  let(:product) { create(:product, stores: [store]) }
  let(:line_item) { create(:line_item, order: order, product: product) }
  let!(:plunk_integration) { create(:plunk_integration, store: store, active: true) }

  subject(:handler) { described_class.new(user: user, store: store) }

  before do
    clear_enqueued_jobs
  end

  it 'is registered as a storefront analytics handler' do
    expect(Rails.application.config.spree.analytics_event_handlers).to include(described_class)
  end

  it 'enqueues cart tracking for product_added' do
    expect {
      handler.handle_event('product_added', { line_item: line_item })
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      plunk_integration.id,
      SpreePlunk::EventNames::CART_ADDED,
      Spree::LineItem.name,
      line_item.id,
      order.email
    )
  end

  it 'enqueues cart tracking for product_removed' do
    expect {
      handler.handle_event('product_removed', { line_item: line_item })
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      plunk_integration.id,
      SpreePlunk::EventNames::CART_REMOVED,
      Spree::LineItem.name,
      line_item.id,
      order.email
    )
  end

  it 'enqueues checkout email tracking with the explicit email override' do
    expect {
      handler.handle_event('checkout_email_entered', { order: order, email: 'checkout@example.com' })
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      plunk_integration.id,
      SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED,
      Spree::Order.name,
      order.id,
      'checkout@example.com'
    )
  end

  it 'enqueues coupon tracking for order-backed events' do
    expect {
      handler.handle_event('coupon_applied', { order: order })
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      plunk_integration.id,
      SpreePlunk::EventNames::COUPON_APPLIED,
      Spree::Order.name,
      order.id,
      order.email
    )
  end

  it 'enqueues checkout-step tracking for order-backed events' do
    expect {
      handler.handle_event('checkout_step_completed', { order: order })
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      plunk_integration.id,
      SpreePlunk::EventNames::CHECKOUT_STEP_COMPLETED,
      Spree::Order.name,
      order.id,
      order.email
    )
  end

  it 'returns early when the primary event resource is missing' do
    expect {
      handler.handle_event('product_added', {})
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end

  it 'returns early when no email can be resolved' do
    order.update!(email: nil)
    email_free_handler = described_class.new(user: nil, store: store)

    expect {
      email_free_handler.handle_event('coupon_denied', { order: order })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end

  it 'returns early when no active Plunk integration is available' do
    plunk_integration.update!(active: false)

    expect {
      handler.handle_event('product_added', { line_item: line_item })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end
end
