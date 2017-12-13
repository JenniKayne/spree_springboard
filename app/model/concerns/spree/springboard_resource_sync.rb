module Spree
  module SpringboardResourceSync
    extend ActiveSupport::Concern
    included do
      scope :springboard_synced, -> {
        left_joins(:springboard_resource).where('spree_springboard_resources.springboard_id IS NOT NULL')
      }
      scope :springboard_not_synced, -> {
        left_joins(:springboard_resource).where('spree_springboard_resources.springboard_id IS NULL')
      }

      def self.find_springboard_synced(springboard_id)
        left_joins(:springboard_resource).
          find_by('spree_springboard_resources.springboard_id = ?', springboard_id)
      end

      def springboard_desync_after; end

      def springboard_desync_before; end

      def springboard_desync!
        springboard_desync_before
        if springboard_resource
          springboard_resource.destroy
        end
        springboard_desync_after
        reload
      end

      def springboard_element(reload = false)
        @springboard_element = springboard_export_class.new.fetch(self) if reload
        @springboard_element ||= springboard_export_class.new.fetch(self)
      end
    end
  end
end
