module SpreePlunk
  class TrackEvent < Base
    prepend ::Spree::ServiceModule::Base

    def call(plunk_integration:, event_name:, resource: nil, email: nil)
      resolved_email = email.presence || resolve_email(resource)
      return noop_result('missing_email') if resolved_email.blank?

      contact_result = ensure_contact(
        plunk_integration: plunk_integration,
        event_name: event_name,
        resource: resource,
        email: resolved_email
      )
      return contact_result if contact_result.failure?

      contact_id = contact_result.value['id']
      return failure_result(
        'missing_contact_id',
        error_message: 'Plunk contact upsert succeeded but did not return a contact id.',
        retryable: true
      ) if contact_id.blank?

      payload = EventPresenter.new(
        event_name: event_name,
        contact_id: contact_id,
        resource: resource,
        store: plunk_integration.store,
        email: resolved_email
      ).call

      plunk_integration.track_event(payload)
    end

    private

    def ensure_contact(plunk_integration:, event_name:, resource:, email:)
      SpreePlunk::UpsertContact.call(
        plunk_integration: plunk_integration,
        user: resolve_user(resource),
        subscriber: resolve_subscriber(resource),
        address: resolve_address(resource),
        email: email,
        subscribed: subscription_state_for(event_name)
      )
    end

    def resolve_user(resource)
      case resource
      when ::Spree::NewsletterSubscriber
        resource.user
      when ::Spree::Order
        resource.user
      when ::Spree::LineItem
        resource.order&.user
      when ::Spree::Shipment
        resource.order&.user
      when ::Spree::Reimbursement
        resource.order&.user
      end
    end

    def resolve_subscriber(resource)
      resource if resource.is_a?(::Spree::NewsletterSubscriber)
    end

    def resolve_address(resource)
      case resource
      when ::Spree::Order
        resource.bill_address || resource.ship_address
      when ::Spree::LineItem
        resource.order&.bill_address || resource.order&.ship_address
      when ::Spree::Shipment
        resource.address || resource.order&.bill_address || resource.order&.ship_address
      when ::Spree::Reimbursement
        resource.order&.bill_address || resource.order&.ship_address
      end
    end

    def resolve_email(resource)
      case resource
      when ::Spree::NewsletterSubscriber
        resource.email
      when ::Spree::Order
        resource.email
      when ::Spree::LineItem
        resource.order&.email
      when ::Spree::Shipment
        resource.order&.email
      when ::Spree::Reimbursement
        resource.order&.email
      when Hash
        resource['email']
      end
    end

    def subscription_state_for(event_name)
      case event_name
      when SpreePlunk::EventNames::NEWSLETTER_SUBSCRIBED
        true
      when SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED
        false
      end
    end

    def failure_result(reason, error_message:, retryable:)
      ::Spree::ServiceModule::Result.new(false, {
        error: reason,
        error_code: reason,
        error_message: error_message,
        retryable: retryable
      })
    end
  end
end
