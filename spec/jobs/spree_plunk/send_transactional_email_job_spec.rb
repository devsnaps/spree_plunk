require 'spec_helper'

RSpec.describe SpreePlunk::SendTransactionalEmailJob, type: :job do
  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  it 'passes event payloads through for password reset sends' do
    payload = {
      'email' => 'buyer@example.com',
      'reset_token' => 'reset-token'
    }

    expect(SpreePlunk::SendTransactionalEmail).to receive(:call).with(
      plunk_integration: integration,
      email_type: SpreePlunk::TransactionalEmailTypes::PASSWORD_RESET,
      resource: nil,
      email: 'buyer@example.com',
      event_payload: payload
    ).and_return(Spree::ServiceModule::Result.new(true, { 'id' => 'email_123' }))

    described_class.perform_now(
      integration.id,
      SpreePlunk::TransactionalEmailTypes::PASSWORD_RESET,
      nil,
      nil,
      'buyer@example.com',
      payload
    )
  end

  it 'reloads order resources before delegating to the send service' do
    order = create(:completed_order_with_totals, store: store, email: 'buyer@example.com')

    expect(SpreePlunk::SendTransactionalEmail).to receive(:call).with(
      plunk_integration: integration,
      email_type: SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND,
      resource: order,
      email: 'buyer@example.com',
      event_payload: { 'id' => order.to_param }
    ).and_return(Spree::ServiceModule::Result.new(true, { 'id' => 'email_123' }))

    described_class.perform_now(
      integration.id,
      SpreePlunk::TransactionalEmailTypes::ORDER_CONFIRMATION_RESEND,
      Spree::Order.name,
      order.id,
      'buyer@example.com',
      { 'id' => order.to_param }
    )
  end
end
