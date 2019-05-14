module SpreeSpringboard
  class ImportVariantJob < ApplicationJob
    queue_as :springboard

    def perform
      import_manager = Spree::Variant.springboard_import_class.new
      import_manager.import_all_perform(SpreeSpringboard.client[:items])
    end
  end
end
