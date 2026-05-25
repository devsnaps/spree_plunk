module SpreePlunk
  module TransactionalEmailTypes
    PASSWORD_RESET = 'password_reset'.freeze
    NEWSLETTER_CONFIRMATION = 'newsletter_confirmation'.freeze
    ORDER_CONFIRMATION = 'order_confirmation'.freeze
    ORDER_CONFIRMATION_RESEND = 'order_confirmation_resend'.freeze
    ORDER_CANCELLATION = 'order_cancellation'.freeze
    SHIPMENT_SHIPPED = 'shipment_shipped'.freeze
    REIMBURSEMENT = 'reimbursement'.freeze

    ALL = [
      PASSWORD_RESET,
      NEWSLETTER_CONFIRMATION,
      ORDER_CONFIRMATION,
      ORDER_CONFIRMATION_RESEND,
      ORDER_CANCELLATION,
      SHIPMENT_SHIPPED,
      REIMBURSEMENT
    ].freeze
  end
end
