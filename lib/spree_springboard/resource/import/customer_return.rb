module SpreeSpringboard
  module Resource
    module Import
      class CustomerReturn < SpreeSpringboard::Resource::Import::Base
        include SpreeSpringboard::Resource::Clients::CustomerReturnClient
        self.spree_class = Spree::CustomerReturn

        #
        # Create ReturnAuthorization from Springboard Return Ticket
        #
        def create_from_springboard_resource(springboard_return)
          # return unless springboard_return[:id] == 137510

          ActiveRecord::Base.transaction do
            # Find invoice entry in Spree::SpringboardResource related to springboard_return
            invoice_resource = find_spree_invoice(springboard_return)

            # Raise exception if no invoice entry is found
            raise "Invoice #{springboard_return[:id]}::NoSpreeInvoice" if invoice_resource.blank?

            # Load order related to the Invoice entry
            order = invoice_resource.parent

            # Create Return Authorization
            return_authorization = create_spree_return_authorization(order, springboard_return)

            # Prepare Spree Return Items and select to match springboard_return_lines
            return_authorization_items = select_spree_return_items(springboard_return, return_authorization)

            # Raise exception if springboard_return_lines do not match available Return Items
            raise "Invoice #{springboard_return[:id]}::NoValidReturnItems" if return_authorization_items.blank?

            # Add Return Items to Return Authorization
            return_authorization.return_items = return_authorization_items
          end
        end

        #
        # Find invoice entry in Spree::SpringboardResource related to springboard_return
        #
        def find_spree_invoice(springboard_return)
          Spree::SpringboardResource.find_by(
            resource_type: 'invoice',
            springboard_id: springboard_return[:parent_transaction_id]
          )
        end

        #
        # Prepare Spree Return Items and select to match springboard_return_lines
        #
        def select_spree_return_items(springboard_return, return_authorization)
          returned_springboard_items = springboard_return_items(springboard_return)
          available_spree_return_items = spree_return_items(return_authorization)
          selected_spree_return_items = []

          returned_springboard_items.each do |springboard_item|
            item_index = find_available_spree_return_item_index(available_spree_return_items, springboard_item)

            if item_index.blank?
              raise "Invoice #{springboard_return[:id]}::NoReturnItem::#{springboard_item[:item_id]}"
            end

            selected_spree_return_items << available_spree_return_items[item_index]
            available_spree_return_items.delete_at(item_index)
          end
        end

        #
        # Helper method - find available Spree ReturnItem in array
        #
        def find_available_spree_return_item_index(available_spree_return_items, springboard_item)
          available_spree_return_items.find_index do |spree_item|
            spree_item.variant.springboard_id == springboard_item[:item_id]
          end
        end

        #
        # Load Return Ticet Lines from Springboard
        #
        def springboard_return_items(springboard_return)
          lines = SpreeSpringboard.
                  client["sales/tickets/#{springboard_return[:id]}/lines"].get.body.results
          used_lines = lines.reject { |line| line.qty.zero? }
          used_lines.map do |line|
            { item_id: line[:item_id], qty: line[:qty] }
          end
        end

        #
        # Create ReturnAuthorization
        #
        def create_spree_return_authorization(order, springboard_return)
          Spree::ReturnAuthorization.create!(
            order: order,
            stock_location: Spree::StockLocation.first,
            return_authorization_reason_id: Spree::ReturnAuthorizationReason.active.first.id,
            memo: "Springboard Return ##{springboard_return[:id]}"
          )
        end

        #
        # Preapre ReturnItems for the created ReturnAuthorization
        #
        def spree_return_items(return_authorization)
          all_inventory_units = return_authorization.order.inventory_units
          associated_inventory_units = return_authorization.return_items.map(&:inventory_unit)
          unassociated_inventory_units = all_inventory_units - associated_inventory_units

          unassociated_inventory_units.map do |new_unit|
            Spree::ReturnItem.new(inventory_unit: new_unit).tap(&:set_default_pre_tax_amount)
          end
        end
      end
    end
  end
end
