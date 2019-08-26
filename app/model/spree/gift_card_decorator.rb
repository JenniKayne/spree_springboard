module Spree
  GiftCard.class_eval do
    include SpringboardResources
    self.springboard_export_class = SpreeSpringboard::Resource::Export::GiftCard
    self.springboard_import_class = SpreeSpringboard::Resource::Import::GiftCard

    after_update_commit :schedule_springboard_adjust_balance

    # Import GC from Springboard to Spree by gc.code
    def self.springboard_import_by_code(code)
      return if code.blank?

      springboard_import_class.import_by_code(code)
    end

    # For a batch of GiftCards - import from Springboard and update Spree balance
    def self.springboard_import_gift_cards_balance(gift_cards)
      springboard_import_class.import_gift_cards_balance(gift_cards)
    end

    # Schedule to update Spree balance (after an update in spree)
    def schedule_springboard_adjust_balance
      return if !springboard_id? || current_value_before_last_save == current_value

      SpreeSpringboard::UpdateGiftCardJob.perform_later(id)
    end

    # Schedule to export a gc from Spree to Springboard (can be used on order completion)
    def schedule_springboard_export
      SpreeSpringboard::ExportGiftCardJob.perform_later(id)
    end

    # Perform balance adjustment from Springboard to Spree
    def spree_adjust_balance!
      springboard_import_class.import_gift_cards_balance([self])
    end

    # Perform balance adjustment from Spree to Springboard
    def springboard_adjust_balance!
      springboard_export_class.adjust_balance(self)
    end
  end
end
