module SpreePlunk
  module PromotionHandlerCouponDecorator
    def apply
      attempted_coupon_code = order.coupon_code
      result = super

      return result unless trackable_coupon_code?(attempted_coupon_code)

      publish_coupon_event('coupon.entered', attempted_coupon_code)

      if successful? && status_code.to_s == 'coupon_code_applied'
        publish_coupon_event('coupon.applied', attempted_coupon_code, status_code: status_code)
      elsif coupon_denied?
        publish_coupon_event(
          'coupon.denied',
          attempted_coupon_code,
          status_code: status_code,
          error_message: error
        )
      end

      result
    end

    def remove(coupon_code)
      result = super

      if successful? && trackable_coupon_code?(coupon_code)
        publish_coupon_event('coupon.removed', coupon_code, status_code: status_code)
      end

      result
    end

    private

    def publish_coupon_event(event_name, coupon_code, status_code: nil, error_message: nil)
      SpreePlunk::StorefrontOrderEventPublisher.publish_coupon_event(
        order: order,
        event_name: event_name,
        coupon_code: coupon_code,
        status_code: status_code,
        error_message: error_message
      )
    end

    def trackable_coupon_code?(coupon_code)
      normalized_code = coupon_code.to_s.strip.downcase
      return false if normalized_code.blank?
      return false if gift_cards_enabled? && order.store&.gift_cards&.find_by(code: normalized_code).present?

      true
    end

    def coupon_denied?
      status = status_code.to_s
      status.start_with?('coupon_code_') && status != 'coupon_code_applied'
    end
  end
end

::Spree::PromotionHandler::Coupon.prepend(SpreePlunk::PromotionHandlerCouponDecorator)
