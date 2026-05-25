module SpreePlunk
  class SendTransactionalEmail < Base
    prepend ::Spree::ServiceModule::Base

    TYPE_CONFIG = {
      TransactionalEmailTypes::PASSWORD_RESET => {
        enabled_preference: :preferred_password_reset_email_enabled,
        presenter: SpreePlunk::PasswordResetEmailPresenter
      },
      TransactionalEmailTypes::NEWSLETTER_CONFIRMATION => {
        enabled_preference: :preferred_newsletter_confirmation_email_enabled,
        presenter: SpreePlunk::NewsletterConfirmationEmailPresenter
      },
      TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND => {
        enabled_preference: :preferred_order_confirmation_resend_email_enabled,
        presenter: SpreePlunk::OrderConfirmationResendEmailPresenter
      }
    }.freeze

    def call(plunk_integration:, email_type:, resource: nil, email: nil, event_payload: nil)
      config = TYPE_CONFIG[email_type.to_s]
      return failure_result('unknown_email_type', "Unknown Plunk transactional email type: #{email_type.inspect}") unless config
      return noop_result('transactional_email_disabled') unless plunk_integration.preferred_transactional_email_enabled
      return noop_result("#{email_type}_disabled") unless plunk_integration.public_send(config[:enabled_preference])

      event_payload = normalized_event_payload(event_payload)
      context_result = validate_context(email_type.to_s, resource, event_payload)
      return context_result if context_result

      payload = config[:presenter].new(
        plunk_integration: plunk_integration,
        resource: resource,
        email: email,
        event_payload: event_payload
      ).call

      validation_result = validate_payload(payload)
      return validation_result if validation_result.failure?

      result = plunk_integration.send_transactional_email(payload)
      mark_order_confirmation_delivered(resource, email_type) if result.success?
      result
    end

    private

    def normalized_event_payload(event_payload)
      return {} if event_payload.blank?

      event_payload.respond_to?(:to_unsafe_h) ? event_payload.to_unsafe_h : event_payload
    end

    def validate_context(email_type, resource, event_payload)
      case email_type
      when TransactionalEmailTypes::PASSWORD_RESET
        return failure_result('missing_reset_token', 'Password reset emails require a reset token.') if event_value(event_payload, :reset_token).blank?
      when TransactionalEmailTypes::NEWSLETTER_CONFIRMATION
        return noop_result('missing_newsletter_subscriber') unless resource
        return noop_result('newsletter_already_verified') if resource.respond_to?(:verified?) && resource.verified?

        token = event_value(event_payload, :verification_token).presence || resource&.verification_token
        return failure_result('missing_verification_token', 'Newsletter confirmation emails require a verification token.') if token.blank?
      when TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND
        return noop_result('missing_order') unless resource
      end

      nil
    end

    def event_value(event_payload, key)
      event_payload[key.to_s] || event_payload[key.to_sym]
    end

    def validate_payload(payload)
      return failure_result('missing_payload', 'No Plunk transactional email payload was built.') unless payload.is_a?(Hash)
      return noop_result('missing_recipient') if payload[:to].blank?

      if payload[:template].blank?
        return failure_result('missing_sender', 'A sender is required when sending a Plunk transactional email without a template.') if payload[:from].blank?
        return failure_result('missing_subject', 'A subject is required when sending a Plunk transactional email without a template.') if payload[:subject].blank?
        return failure_result('missing_body', 'A body is required when sending a Plunk transactional email without a template.') if payload[:body].blank?
      end

      ::Spree::ServiceModule::Result.new(true, {})
    end

    def failure_result(reason, error_message, retryable: false)
      ::Spree::ServiceModule::Result.new(false, {
        error: reason,
        error_code: reason,
        error_message: error_message,
        retryable: retryable
      })
    end

    def mark_order_confirmation_delivered(resource, email_type)
      return unless email_type.to_s == TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND
      return unless resource.respond_to?(:confirmation_delivered?)
      return if resource.confirmation_delivered?

      resource.update_column(:confirmation_delivered, true)
    end
  end
end
