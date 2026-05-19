require 'spec_helper'

RSpec.describe Spree::Checkout::Advance, events: true do
  before do
    Spree::Events.reset!
  end

  after do
    Spree::Events.reset!
  end

  let(:order) { create(:order_ready_to_ship, state: :address, email: 'buyer@example.com') }

  it 'publishes checkout step completed and viewed events when the checkout advance service changes state' do
    received_events = []

    Spree::Events.subscribe('checkout.step_completed', async: false) { |event| received_events << event }
    Spree::Events.subscribe('checkout.step_viewed', async: false) { |event| received_events << event }
    Spree::Events.activate!

    result = described_class.call(order: order, state: 'delivery')

    aggregate_failures do
      expect(result).to be_success
      expect(received_events.map(&:name)).to eq(%w[checkout.step_completed checkout.step_viewed])
      expect(received_events.first.payload).to include('checkout_step' => 'address')
      expect(received_events.second.payload).to include('checkout_step' => 'delivery')
    end
  end
end
