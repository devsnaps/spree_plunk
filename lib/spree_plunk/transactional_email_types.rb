module SpreePlunk
  module TransactionalEmailTypes
    PASSWORD_RESET = 'password_reset'.freeze
    NEWSLETTER_CONFIRMATION = 'newsletter_confirmation'.freeze
    ORDER_CONFIRMATION = 'order_confirmation'.freeze
    ORDER_CONFIRMATION_RESEND = 'order_confirmation_resend'.freeze
    ORDER_CANCELLATION = 'order_cancellation'.freeze
    SHIPMENT_SHIPPED = 'shipment_shipped'.freeze
    REIMBURSEMENT = 'reimbursement'.freeze
    STORE_OWNER_NOTIFICATION = 'store_owner_notification'.freeze
    PAYMENT_LINK = 'payment_link'.freeze

    ALL = [
      PASSWORD_RESET,
      NEWSLETTER_CONFIRMATION,
      ORDER_CONFIRMATION,
      ORDER_CONFIRMATION_RESEND,
      ORDER_CANCELLATION,
      SHIPMENT_SHIPPED,
      REIMBURSEMENT,
      STORE_OWNER_NOTIFICATION,
      PAYMENT_LINK
    ].freeze
  end
end
