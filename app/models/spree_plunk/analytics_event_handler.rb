module SpreePlunk
  class AnalyticsEventHandler < ::Spree::BaseAnalyticsEventHandler
    ORDER_EVENT_NAMES = %w[
      checkout_email_entered
      checkout_step_viewed
      checkout_step_completed
      coupon_entered
      coupon_removed
      coupon_applied
      coupon_denied
    ].freeze

    def client
      @client ||= store&.integrations&.active&.find_by(type: Spree::Integrations::Plunk.name)
    end

    def handle_event(event_name, properties = {})
      integration = client
      return if integration.blank?

      plunk_event_name = EventNames.storefront_analytics_event_name(event_name)
      return if plunk_event_name.blank?

      resource = resource_for(event_name, properties)
      return if resource.blank?

      email = email_for(event_name, properties)
      return if email.blank?

      TrackEventJob.perform_later(
        integration.id,
        plunk_event_name,
        resource&.class&.name,
        resource&.id,
        email
      )
    end

    private

    def resource_for(event_name, properties)
      if ORDER_EVENT_NAMES.include?(event_name.to_s)
        property(properties, :order)
      end
    end

    def email_for(event_name, properties)
      return property(properties, :email).presence || order_email(properties) || user&.email.presence if event_name.to_s == 'checkout_email_entered'

      order_email(properties) || user&.email.presence
    end

    def order_email(properties)
      property(properties, :order)&.email.presence
    end

    def property(properties, key)
      properties[key] || properties[key.to_s]
    end
  end
end
