module SpreePlunk
  class TransactionalEmailSubscriber < Spree::Subscriber
    subscribes_to 'customer.password_reset_requested',
                  'newsletter_subscriber.subscription_requested',
                  'order.completed',
                  'order.canceled',
                  'order.resend_confirmation_email',
                  'shipment.shipped',
                  'reimbursement.reimbursed',
                  async: false

    on 'customer.password_reset_requested', :handle_password_reset_requested
    on 'newsletter_subscriber.subscription_requested', :handle_newsletter_subscription_requested
    on 'order.completed', :handle_order_completed
    on 'order.canceled', :handle_order_canceled
    on 'order.resend_confirmation_email', :handle_order_confirmation_resend
    on 'shipment.shipped', :handle_shipment_shipped
    on 'reimbursement.reimbursed', :handle_reimbursement_reimbursed

    private

    def handle_password_reset_requested(event)
      email = event.payload['email']
      return if email.blank? || event.payload['reset_token'].blank?

      integration = plunk_integration(event)
      return unless enabled_for?(integration, TransactionalEmailTypes::PASSWORD_RESET)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::PASSWORD_RESET,
        nil,
        nil,
        email,
        event.payload
      )
    end

    def handle_newsletter_subscription_requested(event)
      subscriber = find_newsletter_subscriber(event.payload['id'])
      return unless subscriber
      return if subscriber.verified?

      integration = plunk_integration(event, store: resource_store(subscriber), store_id: event.payload['store_id'])
      return unless enabled_for?(integration, TransactionalEmailTypes::NEWSLETTER_CONFIRMATION)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::NEWSLETTER_CONFIRMATION,
        ::Spree::NewsletterSubscriber.name,
        subscriber.id,
        subscriber.email,
        event.payload
      )
    end

    def handle_order_completed(event)
      order = find_order(event.payload['id'])
      return unless order
      return if order.respond_to?(:confirmation_delivered?) && order.confirmation_delivered?
      return if event_value(event.payload, :notify_customer) == false

      integration = plunk_integration(event, store: order.store)
      return unless enabled_for?(integration, TransactionalEmailTypes::ORDER_CONFIRMATION)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::ORDER_CONFIRMATION,
        ::Spree::Order.name,
        order.id,
        order.email,
        event.payload
      )
    end

    def handle_order_canceled(event)
      order = find_order(event.payload['id'])
      return unless order
      return if event_value(event.payload, :notify_customer) == false

      integration = plunk_integration(event, store: order.store)
      return unless enabled_for?(integration, TransactionalEmailTypes::ORDER_CANCELLATION)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::ORDER_CANCELLATION,
        ::Spree::Order.name,
        order.id,
        order.email,
        event.payload
      )
    end

    def handle_order_confirmation_resend(event)
      order = find_order(event.payload['id'])
      return unless order

      integration = plunk_integration(event, store: order.store)
      return unless enabled_for?(integration, TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND,
        ::Spree::Order.name,
        order.id,
        order.email,
        event.payload
      )
    end

    def handle_shipment_shipped(event)
      shipment = find_shipment(event.payload['id'])
      order = shipment&.order
      return unless shipment && order

      integration = plunk_integration(event, store: order.store)
      return unless enabled_for?(integration, TransactionalEmailTypes::SHIPMENT_SHIPPED)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::SHIPMENT_SHIPPED,
        ::Spree::Shipment.name,
        shipment.id,
        order.email,
        event.payload
      )
    end

    def handle_reimbursement_reimbursed(event)
      reimbursement = find_reimbursement(event.payload['id'])
      order = reimbursement&.order
      return unless reimbursement && order

      integration = plunk_integration(event, store: order.store)
      return unless enabled_for?(integration, TransactionalEmailTypes::REIMBURSEMENT)

      SpreePlunk::SendTransactionalEmailJob.perform_later(
        integration.id,
        TransactionalEmailTypes::REIMBURSEMENT,
        ::Spree::Reimbursement.name,
        reimbursement.id,
        order.email,
        event.payload
      )
    end

    def find_newsletter_subscriber(value)
      return if value.blank?

      if ::Spree::NewsletterSubscriber.respond_to?(:find_by_param)
        ::Spree::NewsletterSubscriber.find_by_param(value)
      elsif ::Spree::NewsletterSubscriber.respond_to?(:find_by_prefix_id)
        ::Spree::NewsletterSubscriber.find_by_prefix_id(value)
      else
        ::Spree::NewsletterSubscriber.find_by(id: value)
      end
    end

    def find_order(value)
      return if value.blank?

      if ::Spree::Order.respond_to?(:find_by_param)
        ::Spree::Order.find_by_param(value)
      elsif ::Spree::Order.respond_to?(:find_by_prefix_id)
        ::Spree::Order.find_by_prefix_id(value)
      else
        ::Spree::Order.find_by(id: value)
      end
    end

    def find_shipment(value)
      return if value.blank?

      if ::Spree::Shipment.respond_to?(:find_by_param)
        ::Spree::Shipment.find_by_param(value)
      elsif ::Spree::Shipment.respond_to?(:find_by_prefix_id)
        ::Spree::Shipment.find_by_prefix_id(value)
      else
        ::Spree::Shipment.find_by(id: value)
      end
    end

    def find_reimbursement(value)
      return if value.blank?

      if ::Spree::Reimbursement.respond_to?(:find_by_param)
        ::Spree::Reimbursement.find_by_param(value)
      elsif ::Spree::Reimbursement.respond_to?(:find_by_prefix_id)
        ::Spree::Reimbursement.find_by_prefix_id(value)
      else
        ::Spree::Reimbursement.find_by(id: value)
      end
    end

    def plunk_integration(event, store: nil, store_id: nil)
      store_ids = [
        store&.id,
        resolve_store_id(store_id),
        event.store_id,
        ::Spree::Store.default&.id
      ].compact.uniq

      store_ids.each do |candidate_store_id|
        integration = ::Spree::Integrations::Plunk.find_by(store_id: candidate_store_id)
        return integration if integration
      end

      nil
    end

    def resolve_store_id(value)
      return if value.blank?

      store =
        if ::Spree::Store.respond_to?(:find_by_param)
          ::Spree::Store.find_by_param(value)
        elsif ::Spree::Store.respond_to?(:find_by_prefix_id)
          ::Spree::Store.find_by_prefix_id(value)
        else
          ::Spree::Store.find_by(id: value)
        end

      store&.id
    end

    def resource_store(resource)
      resource.store if resource.respond_to?(:store)
    rescue ActiveModel::MissingAttributeError
      nil
    end

    def enabled_for?(integration, email_type)
      return false unless integration&.preferred_transactional_email_enabled

      case email_type
      when TransactionalEmailTypes::PASSWORD_RESET
        integration.preferred_password_reset_email_enabled
      when TransactionalEmailTypes::NEWSLETTER_CONFIRMATION
        integration.preferred_newsletter_confirmation_email_enabled
      when TransactionalEmailTypes::ORDER_CONFIRMATION
        integration.preferred_order_confirmation_email_enabled
      when TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND
        integration.preferred_order_confirmation_resend_email_enabled
      when TransactionalEmailTypes::ORDER_CANCELLATION
        integration.preferred_order_cancellation_email_enabled
      when TransactionalEmailTypes::SHIPMENT_SHIPPED
        integration.preferred_shipment_shipped_email_enabled
      when TransactionalEmailTypes::REIMBURSEMENT
        integration.preferred_reimbursement_email_enabled
      else
        false
      end
    end

    def event_value(payload, key)
      return payload[key.to_s] if payload.key?(key.to_s)
      return payload[key.to_sym] if payload.key?(key.to_sym)

      nil
    end
  end
end
