module SpreePlunk
  class EventPresenter
    def initialize(event_name:, contact_id:, resource: nil, store: nil, email: nil)
      @event_name = event_name
      @contact_id = contact_id
      @resource = resource
      @store = store
      @email = email
    end

    def call
      payload = {
        name: event_name,
        contactId: contact_id,
        data: event_data
      }

      payload.delete(:data) if payload[:data].empty?
      payload
    end

    private

    attr_reader :event_name, :contact_id, :resource, :store, :email

    def event_data
      case resource
      when ::Spree::Order
        OrderPresenter.new(order: resource, store: store, email: email).call
      when ::Spree::LineItem
        LineItemPresenter.new(line_item: resource, store: store, email: email).call
      when ::Spree::Shipment
        ShipmentPresenter.new(shipment: resource, store: store).call
      when ::Spree::Reimbursement
        ReimbursementPresenter.new(reimbursement: resource, store: store).call
      when ::Spree::NewsletterSubscriber
        NewsletterSubscriberPresenter.new(subscriber: resource, store: store).call
      when Hash
        hash_event_data
      else
        {}
      end
    end

    def hash_event_data
      case event_name
      when SpreePlunk::EventNames::CART_ADDED, SpreePlunk::EventNames::CART_REMOVED
        LineItemPresenter.new(line_item: resource, store: store, email: email).call
      when SpreePlunk::EventNames::CHECKOUT_EMAIL_ENTERED,
           SpreePlunk::EventNames::CHECKOUT_STEP_VIEWED,
           SpreePlunk::EventNames::CHECKOUT_STEP_COMPLETED,
           SpreePlunk::EventNames::COUPON_ENTERED,
           SpreePlunk::EventNames::COUPON_REMOVED,
           SpreePlunk::EventNames::COUPON_APPLIED,
           SpreePlunk::EventNames::COUPON_DENIED
        StorefrontOrderEventPresenter.new(payload: resource, store: store, email: email).call
      else
        NewsletterSubscriberPresenter.new(subscriber: resource, store: store).call
      end
    end
  end
end
