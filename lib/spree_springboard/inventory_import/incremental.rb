module SpreeSpringboard
  module InventoryImport
    class Incremental < SpreeSpringboard::InventoryImport::Base
      #
      # Download incremental stock_data from Sprinboard
      # Do so by getting all the transactions from the last saved transaction ID
      # incrementally update
      #
      def springboard_stock_data(_fail_count = 0)
        # Get inventory transactions since the last id stored in Spree
        last_transaction_id = SpreeSpringboard.springboard_state[:last_transaction_id]
        client_filter = "_filter={\"id\":{\"$gt\":#{last_transaction_id}},\"delta_qty_committed\":{\"$neq\":null}}&per_page=500"
        client_url = '/api/inventory/transactions'

        inventory_transactions_client = SpreeSpringboard.client["#{client_url}?#{client_filter}"]
        inventory_transactions_client.get.body.results
      end

      #
      # ImportType-specific Spree update method
      #
      def update_stock_item(springboard_transaction_item, spree_stock_item)
        spree_stock_item.adjust_count_on_hand(springboard_transaction_item[:delta_qty_committed])
        @new_last_transaction_id = springboard_transaction_item[:id]
      end
    end
  end
end