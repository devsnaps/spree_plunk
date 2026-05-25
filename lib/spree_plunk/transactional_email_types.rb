module SpreePlunk
  module TransactionalEmailTypes
    PASSWORD_RESET = 'password_reset'.freeze
    NEWSLETTER_CONFIRMATION = 'newsletter_confirmation'.freeze
    ORDER_CONFIRMATION_RESEND = 'order_confirmation_resend'.freeze

    ALL = [
      PASSWORD_RESET,
      NEWSLETTER_CONFIRMATION,
      ORDER_CONFIRMATION_RESEND
    ].freeze
  end
end
