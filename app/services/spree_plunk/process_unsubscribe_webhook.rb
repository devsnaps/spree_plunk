require 'digest'
require 'json'

module SpreePlunk
  class ProcessUnsubscribeWebhook < Base
    REPLAY_CACHE_NAMESPACE = 'spree_plunk:subscription_webhook'.freeze
    REPLAY_TTL = 1.day

    def self.replay_cache_store
      return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      @replay_cache_store ||= ActiveSupport::Cache::MemoryStore.new
    end

    def call(plunk_integration:, payload:)
      return noop_result('webhook_disabled') unless plunk_integration&.preferred_unsubscribe_webhook_enabled

      normalized_payload = normalize_payload(payload)
      subscribed = resolved_subscription_state(normalized_payload)
      return noop_result('unsupported_payload') if subscribed.nil?

      email = resolved_email(normalized_payload)
      return noop_result('missing_email') if email.blank?

      delivery_cache_key = replay_cache_key(plunk_integration: plunk_integration, payload: normalized_payload)
      return noop_result('duplicate_delivery') unless claim_delivery!(delivery_cache_key)

      result = local_writeback_service(subscribed).call(email: email)
      release_delivery!(delivery_cache_key) if result.failure?

      result
    end

    private

    BOOLEAN = ActiveModel::Type::Boolean.new

    def normalize_payload(payload)
      payload.to_h.deep_stringify_keys
    end

    def resolved_subscription_state(payload)
      explicit_value = payload.dig('contact', 'subscribed')
      explicit_value = payload['subscribed'] if explicit_value.nil? && payload.key?('subscribed')
      return BOOLEAN.cast(explicit_value) unless explicit_value.nil?

      case event_name(payload)
      when 'contact.subscribed'
        true
      when 'contact.unsubscribed'
        false
      end
    end

    def event_name(payload)
      payload.dig('event', 'name').presence ||
        payload['event_name'].presence ||
        payload['name'].presence
    end

    def resolved_email(payload)
      normalize_email(payload.dig('contact', 'email') || payload['email'])
    end

    def normalize_email(value)
      value.to_s.strip.downcase.presence
    end

    def replay_cache_key(plunk_integration:, payload:)
      [
        REPLAY_CACHE_NAMESPACE,
        plunk_integration.id,
        replay_identifier(payload)
      ].join(':')
    end

    def replay_identifier(payload)
      execution_id = payload.dig('execution', 'id').presence
      return "execution:#{execution_id}" if execution_id

      "digest:#{Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))}"
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) do |key, normalized|
          normalized[key] = canonicalize(value[key])
        end
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    def claim_delivery!(cache_key)
      replay_cache.write(cache_key, true, expires_in: REPLAY_TTL, unless_exist: true)
    end

    def release_delivery!(cache_key)
      replay_cache.delete(cache_key)
    end

    def replay_cache
      self.class.replay_cache_store
    end

    def local_writeback_service(subscribed)
      subscribed ? SpreePlunk::ApplyLocalSubscribe : SpreePlunk::ApplyLocalUnsubscribe
    end
  end
end
