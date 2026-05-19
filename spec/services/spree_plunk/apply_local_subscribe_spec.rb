require 'spec_helper'

RSpec.describe SpreePlunk::ApplyLocalSubscribe do
  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'creates a verified newsletter subscriber and enables user marketing without re-enqueuing outbound sync jobs' do
    user = create(:user, email: 'newsletter@example.com', accepts_email_marketing: false)
    clear_enqueued_jobs

    result = nil

    expect {
      result = described_class.call(email: user.email)
    }.to change(Spree::NewsletterSubscriber, :count).by(1)

    subscriber = Spree::NewsletterSubscriber.find_by!(email: user.email)

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(
        email: 'newsletter@example.com',
        subscribed: true,
        subscriber_id: subscriber.id,
        subscriber_created: true,
        subscriber_verified: true,
        user_updated: true
      )
      expect(subscriber.verified?).to be(true)
      expect(subscriber.user).to eq(user)
      expect(user.reload.accepts_email_marketing).to be(true)
      expect(enqueued_jobs.map { |job| job[:job] }).not_to include(
        SpreePlunk::UpsertContactJob,
        SpreePlunk::SubscribeJob,
        SpreePlunk::UnsubscribeJob,
        SpreePlunk::TrackEventJob
      )
    end
  end

  it 'verifies an existing unverified subscriber and links the matching user' do
    user = create(:user, email: 'newsletter@example.com', accepts_email_marketing: false)
    subscriber = create(:newsletter_subscriber, :unverified, email: user.email, user: nil)

    result = described_class.call(email: user.email)

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(
        email: 'newsletter@example.com',
        subscribed: true,
        subscriber_id: subscriber.id,
        subscriber_created: false,
        subscriber_verified: true,
        user_updated: true
      )
      expect(subscriber.reload.verified?).to be(true)
      expect(subscriber.user).to eq(user)
      expect(user.reload.accepts_email_marketing).to be(true)
    end
  end

  it 'creates a verified subscriber even when no matching user exists locally' do
    result = nil

    expect {
      result = described_class.call(email: 'newsletter@example.com')
    }.to change(Spree::NewsletterSubscriber, :count).by(1)

    subscriber = Spree::NewsletterSubscriber.find_by!(email: 'newsletter@example.com')

    aggregate_failures do
      expect(result).to be_success
      expect(result.value).to include(
        email: 'newsletter@example.com',
        subscribed: true,
        subscriber_id: subscriber.id,
        subscriber_created: true,
        subscriber_verified: true,
        user_updated: false
      )
      expect(subscriber.verified?).to be(true)
      expect(subscriber.user).to be_nil
    end
  end

  it 'acknowledges already-subscribed local state idempotently' do
    user = create(:user, email: 'newsletter@example.com', accepts_email_marketing: true)
    subscriber = create(:newsletter_subscriber, :verified, email: user.email, user: user)

    result = described_class.call(email: user.email)

    expect(result.value).to include(
      email: 'newsletter@example.com',
      subscribed: true,
      subscriber_id: subscriber.id,
      subscriber_created: false,
      subscriber_verified: false,
      user_updated: false
    )
  end
end
