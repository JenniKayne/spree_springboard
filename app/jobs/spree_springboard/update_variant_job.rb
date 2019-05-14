module SpreeSpringboard
  class UpdateVariantJob < ApplicationJob
    queue_as :springboard

    def perform
      Spree::Variant.springboard_import_attributes!
    end
  end
end
