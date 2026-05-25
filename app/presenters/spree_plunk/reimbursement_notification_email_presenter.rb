module SpreePlunk
  class ReimbursementNotificationEmailPresenter < TransactionalEmailPresenter
    def call
      base_payload(
        to: resolved_email,
        subject: "Your #{store_name} reimbursement for order #{order_number}",
        body: body,
        template_id: plunk_integration.preferred_reimbursement_template_id,
        data: reimbursement_data,
        headers: headers(
          email_type: TransactionalEmailTypes::REIMBURSEMENT,
          resource_type: ::Spree::Reimbursement.name,
          resource_id: resource&.id
        )
      )
    end

    private

    def resolved_email
      email.presence || order&.email.presence || order&.user&.email
    end

    def order
      resource&.order
    end

    def order_number
      order&.number
    end

    def reimbursement_data
      return {} unless resource

      SpreePlunk::ReimbursementPresenter.new(reimbursement: resource, store: store).call.merge(
        email_type: TransactionalEmailTypes::REIMBURSEMENT,
        store_name: store_name,
        recipient_email: resolved_email
      )
    end

    def body
      html_document(
        "Your #{store_name} reimbursement",
        paragraphs: [
          "A reimbursement has been processed for order #{order_number}.",
          "You can contact #{store_name} if you have any questions."
        ],
        action_url: storefront_url,
        action_label: "Visit #{store_name}"
      )
    end
  end
end
