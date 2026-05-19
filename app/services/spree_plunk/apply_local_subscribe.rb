module SpreePlunk
  class ApplyLocalSubscribe < Base
    def call(email:)
      normalized_email = normalize_email(email)
      return noop_result('missing_email') if normalized_email.blank?

      subscriber = ::Spree::NewsletterSubscriber.find_by(email: normalized_email)
      user = resolved_user(email: normalized_email, subscriber: subscriber)
      subscriber_created = subscriber.blank?
      subscriber_verified = false
      user_updated = false

      ::Spree::Events.disable do
        ActiveRecord::Base.transaction do
          subscriber, subscriber_verified = ensure_verified_subscriber!(
            email: normalized_email,
            user: user,
            subscriber: subscriber
          )
          user_updated = subscribe_user!(subscriber.user || user)
        end
      end

      success(
        email: normalized_email,
        subscribed: true,
        subscriber_id: subscriber.id,
        subscriber_created: subscriber_created,
        subscriber_verified: subscriber_verified,
        user_updated: user_updated
      )
    rescue ActiveRecord::ActiveRecordError => e
      failure(
        {
          error_class: e.class.name,
          error_message: e.message,
          email: normalized_email,
          reason: 'persistence_error'
        },
        e.message
      )
    end

    private

    def normalize_email(value)
      value.to_s.strip.downcase.presence
    end

    def resolved_user(email:, subscriber:)
      subscriber&.user || ::Spree.user_class.find_by(email: email)
    end

    def ensure_verified_subscriber!(email:, user:, subscriber:)
      subscriber ||= ::Spree::NewsletterSubscriber.new(email: email)
      subscriber.user ||= user

      already_verified = subscriber.verified?
      subscriber.assign_attributes(
        email: email,
        user: subscriber.user,
        verified_at: subscriber.verified_at || Time.current,
        verification_token: nil
      )
      subscriber.save!

      [subscriber, !already_verified]
    end

    def subscribe_user!(user)
      return false unless user&.respond_to?(:accepts_email_marketing=)
      return false if user.accepts_email_marketing?

      user.update!(accepts_email_marketing: true)
      true
    end
  end
end
