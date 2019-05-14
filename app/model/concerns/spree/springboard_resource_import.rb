module Spree
  module SpringboardResourceImport
    extend ActiveSupport::Concern
    included do
      class_attribute :springboard_import_class

      def springboard_import!(new_springboard_id = nil)
        return false unless springboard_import_class.present?

        if new_springboard_id.present?
          self.springboard_id = new_springboard_id
        elsif springboard_id.blank?
          return false
        end

        import_manager = springboard_import_class.new
        sync_result = import_manager.sync!(self) != false
        reload
        sync_result
      end

      def self.springboard_import_all!
        return false unless springboard_import_class.present?

        import_manager = springboard_import_class.new
        import_manager.import_all!
      rescue StandardError => error
        class_name = name.demodulize.titleize.pluralize

        Raven.extra_context(import_class_name: class_name)

        raise error
      end
    end
  end
end
