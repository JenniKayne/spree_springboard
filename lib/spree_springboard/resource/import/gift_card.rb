module SpreeSpringboard
  module Resource
    module Import
      class GiftCard < SpreeSpringboard::Resource::Import::Base
        include SpreeSpringboard::Resource::Clients::GiftCardClient
        self.spree_class = Spree::GiftCard

        class << self
          def import_gift_cards_balance(gift_cards)
            springboard_gift_card_numbers = gift_cards.map { |g| g.code.upcase }
            return true if springboard_gift_card_numbers.empty?

            result = SpreeSpringboard.
                     client[:gift_cards].
                     query(_filter: { number: { '$in' => springboard_gift_card_numbers } }).
                     get
            return false unless result && result.success?

            result.body.results.each do |springboard_gift_card|
              gift_card = gift_cards.find { |g| g.code.upcase == springboard_gift_card.number }
              next if gift_card.blank?

              delta = gift_card.current_value - springboard_gift_card.balance
              next if delta.zero?
              Spree::GiftCardTransaction.create!(
                gift_card: gift_card,
                amount: delta
              )

              # Skip after update commit for GiftCard
              gift_card.update_column(:current_value, springboard_gift_card.balance)
            end
            true
          end

          def import_by_code(code)
            return if code.blank?
            result = SpreeSpringboard.client[:gift_cards][code].get
            return unless result && result.success?
            springboard_gift_card = result.body
            return false if springboard_gift_card.blank?

            create_from_springboard_resource(springboard_gift_card)
          end

          def create_from_springboard_resource(springboard_resource)
            variant = Spree::Product.not_deleted.gift_cards.not_e_gift_cards.first.master
            gift_card = Spree::GiftCard.create!(
              code: springboard_resource.number,
              current_value: springboard_resource.balance,
              original_value: springboard_resource.balance,
              variant: variant
            )
            gift_card.springboard_id = springboard_resource.id

            gift_card
          end
        end
      end
    end
  end
end
