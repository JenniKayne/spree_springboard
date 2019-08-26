module SpreeSpringboard
  class ExportGiftCardJob < ApplicationJob
    queue_as :springboard

    def perform(gift_card_id)
      gift_card = Spree::GiftCard.find(gift_card_id)

      return if gift_card.springboard_id.present?

      # Check if GC already exists in Springboard
      response = SpreeSpringboard.client[:gift_cards][gift_card.code].get
      if response.success?
        gift_card.springboard_id = response.body.id
      else
        gift_card.springboard_export!
      end
    rescue StandardError => e
      Raven.extra_context(exporter_gift_card: gift_card.code)

      raise e
    end
  end
end
