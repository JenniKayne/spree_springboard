module SpreeSpringboard
  class UpdateGiftCardJob < ApplicationJob
    queue_as :springboard

    def perform(gift_card_id)
      gift_card = Spree::GiftCard.find(gift_card_id)

      gift_card.springboard_adjust_balance!
    rescue StandardError => e
      Raven.extra_context(updated_gift_card: gift_card.code)

      raise e
    end
  end
end
