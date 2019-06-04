module Spree
  Variant.class_eval do
    include SpringboardResources
    self.springboard_import_class = SpreeSpringboard::Resource::Import::Variant

    # Perform variant attributes import from Springboard
    def self.springboard_import_attributes!
      return false unless springboard_import_class.present?

      import_manager = springboard_import_class.new
      import_manager.import_attributes!
    end
  end
end
