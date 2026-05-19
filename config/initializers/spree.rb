Rails.application.config.after_initialize do
  Rails.application.config.spree.integrations << Spree::Integrations::Plunk
  Rails.application.config.spree.analytics_event_handlers << SpreePlunk::AnalyticsEventHandler
  Spree.subscribers << SpreePlunk::CartSubscriber
  Spree.subscribers << SpreePlunk::ContactSubscriber
  Spree.subscribers << SpreePlunk::NewsletterSubscriber
  Spree.subscribers << SpreePlunk::OrderSubscriber
  Spree.subscribers << SpreePlunk::ShipmentSubscriber
  Spree.subscribers << SpreePlunk::ReimbursementSubscriber
end
