module SpreePlunk
  class TransactionalEmailSubscriber < Spree::Subscriber
    subscribes_to 'customer.password_reset_requested',
                  'newsletter_subscriber.subscription_requested',
                  'order.resend_confirmation_email',
                  async: false

    on 'customer.password_reset_requested', :handle_password_reset_requested
    on 'newsletter_subscriber.subscription_requested', :handle_newsletter_subscription_requested
    on 'order.resend_confirmation_email', :handle_order_confirmation_resend

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
      when TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND
        integration.preferred_order_confirmation_resend_email_enabled
      else
        false
      end
    end
  end
end
