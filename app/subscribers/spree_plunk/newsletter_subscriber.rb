module SpreePlunk
  class NewsletterSubscriber < Spree::Subscriber
    subscribes_to 'newsletter_subscriber.created', 'newsletter_subscriber.verified', 'newsletter_subscriber.deleted', async: false

    on 'newsletter_subscriber.created', :handle_subscriber_created
    on 'newsletter_subscriber.verified', :handle_subscriber_verified
    on 'newsletter_subscriber.deleted', :handle_subscriber_deletion

    private

    def handle_subscriber_created(event)
      subscriber = find_subscriber(event.payload['id'])
      return unless subscriber

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::UpsertContactJob.perform_later(integration.id, ::Spree::NewsletterSubscriber.name, subscriber.id)
    end

    def handle_subscriber_verified(event)
      subscriber = find_subscriber(event.payload['id'])
      return unless subscriber

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::SubscribeJob.perform_later(integration.id, subscriber.id)
      SpreePlunk::TrackEventJob.perform_later(
        integration.id,
        SpreePlunk::EventNames::NEWSLETTER_SUBSCRIBED,
        ::Spree::NewsletterSubscriber.name,
        subscriber.id,
        subscriber.email
      )
    end

    def handle_subscriber_deletion(event)
      email = event.payload['email']
      return if email.blank?

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::UnsubscribeJob.perform_later(integration.id, email)
      SpreePlunk::TrackEventJob.perform_later(
        integration.id,
        SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
        nil,
        nil,
        email,
        event.payload
      )
    end

    def find_subscriber(value)
      return if value.blank?

      if ::Spree::NewsletterSubscriber.respond_to?(:find_by_param)
        ::Spree::NewsletterSubscriber.find_by_param(value)
      elsif ::Spree::NewsletterSubscriber.respond_to?(:find_by_prefix_id)
        ::Spree::NewsletterSubscriber.find_by_prefix_id(value)
      else
        ::Spree::NewsletterSubscriber.find_by(id: value)
      end
    end

    def plunk_integration(event)
      [event.store_id.presence, ::Spree::Store.default&.id].compact.uniq.each do |store_id|
        integration = ::Spree::Integrations::Plunk.find_by(store_id: store_id)
        return integration if integration
      end

      nil
    end
  end
end
