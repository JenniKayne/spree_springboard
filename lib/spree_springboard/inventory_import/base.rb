module SpreeSpringboard
  module InventoryImport
    class Base
      def initialize
        @in_progress = false
        @new_last_transaction_id = nil
      end

      #
      # Perform stock quantity data import from Springboard
      #
      def perform
        lock
        Spree::StockLocation.springboard_synced.each do |stock_location|
          begin
            @new_last_transaction_id = nil
            # Load stock data from Springboard
            springboard_stock = springboard_stock_data(stock_location)

            # Import each stock dota item
            springboard_stock.each do |springboard_stock_item|
              begin
                import_stock_item(stock_location, springboard_stock_item)
              rescue StandardError => error
                log(error, data:
                           {
                             msg: 'Inventory Item Import Failed',
                             stock_location: stock_location.name,
                             springboard_stock_item: springboard_stock_item
                           })
                next
              end
            end
          rescue StandardError => error
            log(error, data: { msg: 'Inventory Import Failed' })
            next
          ensure
            ensure_last_transaction_id_updated(stock_location)
          end
        end
      ensure
        # unlock only if this is the locking process
        unlock if @in_progress
      end

      def ensure_last_transaction_id_updated(stock_location)
        if @in_progress && @new_last_transaction_id.present?
          stock_location.set_child_springboard_id('last_transaction_id', @new_last_transaction_id)
        end
      end

      #
      # Mutex - there can be only one import at a time
      #
      def in_progress?
        @in_progress
      end

      def lock
        raise 'Inventory import already in progress' if SpreeSpringboard.springboard_state[:inventory_import_in_progress]

        SpreeSpringboard.springboard_state[:inventory_import_in_progress] = true
        @in_progress = true # set only for the locking process
      end

      def unlock
        SpreeSpringboard.springboard_state[:inventory_import_in_progress] = false
      end

      #
      # Log handler
      #
      def log(error, params)
        Raven.extra_context(params)
        Raven.capture_exception(error)
      end

      #
      # Update variant's stock level using stock_item data from Springboard
      #
      def import_stock_item(stock_location, springboard_stock_item)
        variant = Spree::Variant.find_by_springboard_id(springboard_stock_item[:item_id])
        return if variant.nil?

        spree_stock_item = variant.stock_items.find_by(stock_location: stock_location) || stock_location.propagate_variant(variant)
        update_stock_item(springboard_stock_item, spree_stock_item)
        variant
      end

      #
      # ImportType-specific Spree update method
      #
      def update_stock_item(_springboard_stock_item, _spree_stock_item)
        raise 'Implement for each Inventory Import type'
      end
    end
  end
end
