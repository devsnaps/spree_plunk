require 'spec_helper'

RSpec.describe SpreePlunk::TrackEvent do
  subject(:result) do
    described_class.call(
      plunk_integration: plunk_integration,
      event_name: event_name,
      resource: resource,
      email: email
    )
  end

  let(:store) { create(:store, code: 'default-store') }
  let(:plunk_integration) do
    instance_double(
      Spree::Integrations::Plunk,
      store: store,
      track_event: track_result
    )
  end
  let(:track_result) { Spree::ServiceModule::Result.new(true, { 'id' => 'evt_123' }) }
  let(:contact_result) { Spree::ServiceModule::Result.new(true, { 'id' => 'cnt_123' }) }
  let(:event_name) { SpreePlunk::EventNames::ORDER_COMPLETED }
  let(:email) { nil }
  let(:user) { create(:user, email: 'buyer@example.com', accepts_email_marketing: true) }
  let(:resource) { create(:completed_order_with_totals, store: store, user: user, email: user.email) }

  before do
    allow(SpreePlunk::UpsertContact).to receive(:call).and_return(contact_result)
  end

  it 'reuses the customer marketing consent when ensuring the contact exists' do
    expect(SpreePlunk::UpsertContact).to receive(:call).with(
      hash_including(
        plunk_integration: plunk_integration,
        user: resource.user,
        address: resource.bill_address,
        email: resource.email,
        subscribed: nil
      )
    ).and_return(contact_result)

    expect(plunk_integration).to receive(:track_event).with(
      hash_including(
        name: SpreePlunk::EventNames::ORDER_COMPLETED,
        contactId: 'cnt_123'
      )
    ).and_return(track_result)

    expect(result).to be_success
  end

  context 'when tracking a shipped shipment event' do
    let(:event_name) { SpreePlunk::EventNames::SHIPMENT_SHIPPED }
    let(:resource) do
      create(:shipped_order, store: store, user: user, email: user.email).shipments.first.tap do |shipment|
        shipment.update_column(:shipped_at, Time.utc(2026, 5, 18, 10, 0, 0))
      end
    end

    it 'builds shipment payload details without overriding the customer consent state' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          plunk_integration: plunk_integration,
          user: resource.order.user,
          address: resource.address || resource.order.bill_address || resource.order.ship_address,
          email: resource.order.email,
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::SHIPMENT_SHIPPED,
          contactId: 'cnt_123',
          data: hash_including(
            shipment_number: resource.number,
            tracking: resource.tracking,
            order_number: resource.order.number,
            store_code: 'default-store',
            shipped_at: resource.shipped_at.iso8601
          )
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a cart event from a line item' do
    let(:event_name) { SpreePlunk::EventNames::CART_ADDED }
    let(:resource) do
      order = create(:order, store: store, user: user, email: user.email)
      product = create(:product, stores: [store])

      create(:line_item, order: order, product: product, quantity: 2, price: 19.99, currency: 'USD')
    end

    it 'ensures the cart contact using the line-item order context and sends cart payload data' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          plunk_integration: plunk_integration,
          user: resource.order.user,
          address: resource.order.bill_address || resource.order.ship_address,
          email: resource.order.email,
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::CART_ADDED,
          contactId: 'cnt_123',
          data: hash_including(
            line_item_id: resource.prefixed_id,
            order_id: resource.order.prefixed_id,
            email: resource.order.email,
            quantity: resource.quantity
          )
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a cart event from a payload snapshot' do
    let(:event_name) { SpreePlunk::EventNames::CART_ADDED }
    let(:order_resource) { create(:order, store: store, user: user, email: nil) }
    let(:resource) do
      {
        'email' => user.email,
        'user_id' => user.id,
        'order_record_id' => order_resource.id,
        'line_item_id' => 'li_123',
        'order_id' => order_resource.prefixed_id,
        'order_number' => order_resource.number,
        'quantity' => 2,
        'unit_price' => 19.99,
        'line_item_total' => 39.98,
        'currency' => order_resource.currency,
        'product_name' => 'Product 1',
        'sku' => 'SKU-1'
      }
    end
    let(:email) { user.email }

    it 'reuses the snapshot user and order context when ensuring the contact exists' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          user: user,
          address: order_resource.bill_address || order_resource.ship_address,
          email: user.email,
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::CART_ADDED,
          contactId: 'cnt_123',
          data: hash_including(
            line_item_id: 'li_123',
            order_id: order_resource.prefixed_id,
            email: user.email,
            quantity: 2
          )
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a checkout event from a payload snapshot' do
    let(:event_name) { SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED }
    let(:order_resource) { create(:order, store: store, user: user, email: nil) }
    let(:resource) do
      {
        'email' => user.email,
        'user_id' => user.id,
        'store_id' => store.id,
        'order_record_id' => order_resource.id,
        'order_id' => order_resource.prefixed_id,
        'order_number' => order_resource.number,
        'checkout_step' => 'address',
        'current_checkout_step' => 'address'
      }
    end
    let(:email) { user.email }

    it 'reuses the snapshot user and order context when ensuring the checkout contact exists' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          user: user,
          address: order_resource.bill_address || order_resource.ship_address,
          email: user.email,
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED,
          contactId: 'cnt_123',
          data: hash_including(
            order_id: order_resource.prefixed_id,
            email: user.email,
            checkout_step: 'address'
          )
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a reimbursement event' do
    let(:event_name) { SpreePlunk::EventNames::REIMBURSEMENT_PAID }
    let(:resource) do
      create(:reimbursement).tap do |reimbursement|
        reimbursement.order.update!(user: user, email: user.email)
      end
    end

    it 'builds reimbursement payload details without overriding the customer consent state' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          plunk_integration: plunk_integration,
          user: resource.order.user,
          address: resource.order.bill_address || resource.order.ship_address,
          email: resource.order.email,
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::REIMBURSEMENT_PAID,
          contactId: 'cnt_123',
          data: hash_including(
            reimbursement_number: resource.number,
            reimbursement_status: resource.reimbursement_status,
            order_number: resource.order.number,
            paid_amount: resource.paid_amount.to_f,
            return_items_count: resource.return_items.size,
            store_code: 'default-store'
          )
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a newsletter subscription event' do
    let(:event_name) { SpreePlunk::EventNames::NEWSLETTER_SUBSCRIBED }
    let(:resource) { create(:newsletter_subscriber, :verified, email: 'newsletter@example.com') }

    it 'upserts the contact as subscribed before tracking' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          subscriber: resource,
          email: 'newsletter@example.com',
          subscribed: true
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking checkout email entry with an explicit email override' do
    let(:event_name) { SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED }
    let(:email) { 'checkout@example.com' }

    it 'uses the explicit email for contact ensure-upsert and payload generation' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          user: resource.user,
          address: resource.bill_address,
          email: 'checkout@example.com',
          subscribed: nil
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).with(
        hash_including(
          name: SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED,
          contactId: 'cnt_123',
          data: hash_including(email: 'checkout@example.com')
        )
      ).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when tracking a newsletter unsubscribe event' do
    let(:event_name) { SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED }
    let(:resource) { { 'email' => 'newsletter@example.com' } }
    let(:email) { 'newsletter@example.com' }

    it 'forces the ensured contact into an unsubscribed state before tracking' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          email: 'newsletter@example.com',
          subscribed: false
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when no email can be resolved' do
    let(:resource) { nil }

    it 'returns a noop result and does not track the event' do
      expect(SpreePlunk::UpsertContact).not_to receive(:call)
      expect(plunk_integration).not_to receive(:track_event)

      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'missing_email')
    end
  end

  context 'when the upserted contact payload does not include an id' do
    let(:contact_result) { Spree::ServiceModule::Result.new(true, {}) }

    it 'returns a retryable failure so the async job can try again' do
      expect(plunk_integration).not_to receive(:track_event)

      expect(result).to be_failure
      expect(result.value).to include(
        error: 'missing_contact_id',
        error_code: 'missing_contact_id',
        retryable: true
      )
      expect(result.value[:error_message]).to include('did not return a contact id')
    end
  end
end
