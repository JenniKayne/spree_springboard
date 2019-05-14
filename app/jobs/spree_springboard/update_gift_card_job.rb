module SpreeSpringboard
  class UpdateGiftCardJob < ApplicationJob
    queue_as :springboard

    def perform(gift_card)
      gift_card.springboard_adjust_balance!
    rescue StandardError => error
      Raven.extra_context(updated_gift_card: gift_card.code)

      raise error
    end
  end
end
