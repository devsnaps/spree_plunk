module SpreePlunk
  module CheckoutAdvanceDecorator
    def call(order:, state: nil, shipping_method_id: nil)
      previous_state = order.state
      result = super

      return result if result.failure?
      return result if previous_state == order.state

      SpreePlunk::StorefrontOrderEventPublisher.publish_checkout_step_events(
        order: order,
        previous_state: previous_state,
        current_state: order.state
      )

      result
    end
  end
end

::Spree::Checkout::Advance.prepend(SpreePlunk::CheckoutAdvanceDecorator)
