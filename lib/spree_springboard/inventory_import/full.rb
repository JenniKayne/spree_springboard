module SpreeSpringboard
  module InventoryImport
    class Full < SpreeSpringboard::InventoryImport::Base
      #
      # Download full stock_data from Sprinboard
      # Make sure there are no transactions during data download
      #
      def springboard_stock_data(stock_location, fail_count = 0)
        fail_count > 3 && raise('Cannot Load Full Stock Data')

        # Get last transaction ID #1
        last_transaction_id1 = springboard_last_transaction_id(stock_location)

        # Get stock for all the products
        client = SpreeSpringboard.client['/api/inventory/values']

        full_stock_data = client.
                          query(group: [:item_id, :location_id],
                                location_id: stock_location.springboard_id,
                                per_page: :all).
                          get.body.results

        # Get last transaction ID #2
        last_transaction_id2 = springboard_last_transaction_id(stock_location)

        # On unsuccessful data download or if transactionID#1 is different from transactionID#2 then try again
        #   try again
        # On successful data download and with matching transactionIDs
        #   save last_transaction_id for future incremental imports
        #   return full stock data
        if full_stock_data.blank? || last_transaction_id1 != last_transaction_id2
          springboard_stock_data(stock_location, fail_count + 1)
        else
          @new_last_transaction_id = last_transaction_id1
          full_stock_data
        end
      end

      #
      # Get last transaction ID from Springboard
      #
      def springboard_last_transaction_id(stock_location, fail_count = 0)
        fail_count > 3 && raise('Cannot Load Last Transaction ID')

        # Get number of transactions
        client_url = "/api/inventory/transactions?location_id=#{stock_location.springboard_id}&per_page=1"
        number_of_transactions = SpreeSpringboard.client[client_url].get.body.total

        # Get the last transaction
        client_url += "&page=#{number_of_transactions}"
        last_transaction = SpreeSpringboard.client[client_url].get.body.results.first

        # Return transaction ID
        if last_transaction.blank? || last_transaction[:id].blank?
          springboard_last_transaction_id(stock_location, fail_count + 1)
        else
          last_transaction[:id]
        end
      end

      #
      # ImportType-specific Spree update method
      #
      def update_stock_item(springboard_stock_item, spree_stock_item)
        if spree_stock_item.count_on_hand != springboard_stock_item[:qty_available]
          new_count_on_hand = [
            springboard_stock_item[:qty_available].to_i,
            0
          ].max
          spree_stock_item.set_count_on_hand(new_count_on_hand)
        end
      end
    end
  end
end
