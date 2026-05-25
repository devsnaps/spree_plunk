module SpreePlunk
  module PaymentLinksControllerDecorator
    def create
      recipient_email = @order.user&.email || @order.email

      if recipient_email.blank?
        flash[:error] = Spree.t('admin.orders.no_email_present')
      elsif plunk_payment_link_handoff_enabled?
        enqueue_plunk_payment_link(recipient_email)
        flash[:success] = Spree.t('admin.orders.payment_link_sent')
      elsif spree_order_mailer_payment_link_available?
        Spree::OrderMailer.payment_link_email(@order.id).deliver_later
        flash[:success] = Spree.t('admin.orders.payment_link_sent')
      else
        flash[:error] = 'Payment link email is not configured.'
      end

      redirect_back fallback_location: spree.edit_admin_order_url(@order)
    end

    private

    def plunk_payment_link_handoff_enabled?
      plunk_payment_link_integration&.preferred_transactional_email_enabled &&
        plunk_payment_link_integration.preferred_payment_link_email_enabled
    end

    def enqueue_plunk_payment_link(recipient_email)
      SpreePlunk::SendTransactionalEmailJob.perform_later(
        plunk_payment_link_integration.id,
        SpreePlunk::TransactionalEmailTypes::PAYMENT_LINK,
        ::Spree::Order.name,
        @order.id,
        recipient_email,
        { 'payment_url' => plunk_payment_url }
      )
    end

    def plunk_payment_url
      spree.checkout_state_url(@order.token, :payment, host: @order.store.storefront_url)
    end

    def plunk_payment_link_integration
      @plunk_payment_link_integration ||= ::Spree::Integrations::Plunk.find_by(store_id: @order.store_id)
    end

    def spree_order_mailer_payment_link_available?
      defined?(::Spree::OrderMailer) && ::Spree::OrderMailer.respond_to?(:payment_link_email)
    end
  end
end

::Spree::Admin::Orders::PaymentLinksController.prepend(SpreePlunk::PaymentLinksControllerDecorator)
