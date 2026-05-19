require 'spec_helper'

RSpec.describe SpreePlunk::AnalyticsEventHandler do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:user) { create(:user, email: 'user@example.com') }
  let(:order) { create(:order, user: user, store: store, email: 'order@example.com') }
  let!(:plunk_integration) { create(:plunk_integration, store: store, active: true) }

  subject(:handler) { described_class.new(user: user, store: store) }

  before do
    clear_enqueued_jobs
  end

  it 'is registered as a storefront analytics handler' do
    expect(Rails.application.config.spree.analytics_event_handlers).to include(described_class)
  end

  it 'ignores checkout events because they are sourced from server-side services' do
    expect {
      handler.handle_event('checkout_email_entered', { order: order, email: 'checkout@example.com' })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end

  it 'ignores coupon events because they are sourced from the coupon handler lifecycle' do
    expect {
      handler.handle_event('coupon_applied', { order: order })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end

  it 'ignores checkout step events because they are sourced from checkout services' do
    expect {
      handler.handle_event('checkout_step_completed', { order: order })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end

  it 'returns early when the primary event resource is missing' do
    expect {
      handler.handle_event('coupon_applied', {})
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
      handler.handle_event('coupon_applied', { order: order })
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end
end
