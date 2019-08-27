module SpreeSpringboard
  class UpdateGiftCardJob < ApplicationJob
    queue_as :springboard

    def perform(gift_card_id)
      gift_card = if gift_card_id.is_a? Integer
                    Spree::GiftCard.find(gift_card_id)
                  else
                    gift_card_id
                  end

      gift_card.springboard_adjust_balance!
    rescue StandardError => e
      Raven.extra_context(gift_card: gift_card, updated_gift_card: gift_card&.code)

      raise e
    end
  end
end
