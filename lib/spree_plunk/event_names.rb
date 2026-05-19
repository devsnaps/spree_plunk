module SpreePlunk
  module EventNames
    CART_ADDED = 'spree.cart.added'.freeze
    CART_REMOVED = 'spree.cart.removed'.freeze
    CHECKOUT_EMAIL_ENTERED = 'spree.checkout.email_entered'.freeze
    CHECKOUT_STEP_VIEWED = 'spree.checkout.step_viewed'.freeze
    CHECKOUT_STEP_COMPLETED = 'spree.checkout.step_completed'.freeze
    COUPON_ENTERED = 'spree.coupon.entered'.freeze
    COUPON_REMOVED = 'spree.coupon.removed'.freeze
    COUPON_APPLIED = 'spree.coupon.applied'.freeze
    COUPON_DENIED = 'spree.coupon.denied'.freeze
    NEWSLETTER_SUBSCRIBED = 'spree.newsletter.subscribed'.freeze
    NEWSLETTER_UNSUBSCRIBED = 'spree.newsletter.unsubscribed'.freeze
    ORDER_COMPLETED = 'spree.order.completed'.freeze
    ORDER_CANCELED = 'spree.order.canceled'.freeze
    SHIPMENT_SHIPPED = 'spree.shipment.shipped'.freeze
    REIMBURSEMENT_PAID = 'spree.reimbursement.paid'.freeze

    STOREFRONT_ANALYTICS_EVENT_MAP = {
      'product_added' => CART_ADDED,
      'product_removed' => CART_REMOVED,
      'checkout_email_entered' => CHECKOUT_EMAIL_ENTERED,
      'checkout_step_viewed' => CHECKOUT_STEP_VIEWED,
      'checkout_step_completed' => CHECKOUT_STEP_COMPLETED,
      'coupon_entered' => COUPON_ENTERED,
      'coupon_removed' => COUPON_REMOVED,
      'coupon_applied' => COUPON_APPLIED,
      'coupon_denied' => COUPON_DENIED
    }.freeze

    def self.storefront_analytics_event_name(event_name)
      STOREFRONT_ANALYTICS_EVENT_MAP[event_name.to_s]
    end
  end
end
