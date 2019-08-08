module SpreeSpringboard
  module Resource
    module Export
      class Order < SpreeSpringboard::Resource::Export::Base
        include SpreeSpringboard::Resource::Clients::OrderClient

        def after_sync(order)
          # Update springboard_exported_at column
          if order.springboard_exported_at.nil? && order.springboard_synced_at.present?
            order.update(springboard_exported_at: order.springboard_synced_at)
          end

          # Create or Update line items
          order.line_items.springboard_not_synced.
            each { |line_item| line_item.springboard_export!(parent: order) }

          # Create Taxes (reset taxes first if needed)
          springboard_tax_sync!(order)
          spree_taxes(order).springboard_not_synced.
            each { |tax| tax.springboard_export!(parent: order) }

          # Create payments
          order.payments.valid.springboard_not_synced.
            each { |payment| payment.springboard_export!(parent: order) }

          # Open order if possible
          springboard_open!(order)
        end

        #
        # Springboard actions
        #

        def springboard_invoice!(order)
          return unless springboard_order_invoiceable?(order)

          fetch_or_create_springboard_invoice_id(order).tap do |invoice_springboard_id|
            springboard_invoice_line_items_create!(order, invoice_springboard_id)
            springboard_invoice_complete!(order)
          end
        end

        def fetch_or_create_springboard_invoice_id(order)
          order.child_springboard_id('invoice') || springboard_invoice_create!(order)
        end

        def springboard_invoice_complete!(order)
          endpoint = "api/sales/invoices/#{order.child_springboard_id('invoice')}"
          client = SpreeSpringboard.client[endpoint]
          response = client.put(status: 'complete')

          response&.success?
        end

        def springboard_invoice_create!(order)
          # returns invoice_springboard_id
          SpreeSpringboard::Resource::Export::Base.
            sync_parent!('api/sales/invoices', 'invoice', springboard_invoice_params(order), order)
        end

        def springboard_invoice_line_items_create!(order, invoice_springboard_id)
          invoice_lines_endpoint = "api/sales/invoices/#{invoice_springboard_id}/lines"
          order.line_items.each do |line_item|
            SpreeSpringboard::Resource::Export::Base.
              sync_parent!(invoice_lines_endpoint, 'invoice_line', springboard_invoice_line_params(line_item), order)
          end

          invoice_lines_client = SpreeSpringboard.client[invoice_lines_endpoint]
          resources = invoice_lines_client.get
          if resources
            resources.body.results.each do |result|
              order.set_child_springboard_id('invoice_line', result[:id])
            end
          end
        end

        def springboard_open!(order)
          update(order, status: 'open') if order.springboard_element[:status] == 'pending'
        end

        def springboard_tax_sync!(order)
          # Create Taxes (remove all first if needed)
          springboard_tax = calculate_springboard_tax_total(order)
          if springboard_tax.positive? && springboard_tax != spree_taxes(order).sum(:amount)
            # Remove tax sync data
            spree_taxes(order).each(&:springboard_desync!)

            # Reset tax value in Springboard
            SpreeSpringboard.client["sales/orders/#{order.springboard_id}/taxes"].
              post(description: 'Tax reset', value: -springboard_tax)
          end
        end

        #
        # Params preparation
        #

        def calculate_springboard_tax_total(order)
          result = SpreeSpringboard.client["sales/orders/#{order.springboard_id}/taxes"].query(per_page: 1000).get
          raise "Springboard Order #{order_springboard_id} missing" unless result&.success?

          result.body.results.map(&:value).sum
        end

        def export_params(order, _params = {})
          # Sync user or create guest user in Springboard
          springboard_user_id = prepare_springboard_user_id(order)

          # Sync addresses for the above user
          billing_address_id = prepare_springboard_address_id(order, 'bill_address', springboard_user_id)
          shipping_address_id = prepare_springboard_address_id(order, 'ship_address', springboard_user_id)
          source_location_id = export_params_source_location_id(order)
          return {} unless source_location_id.present?

          {
            custom: {
              ecommerce_number: order.number
            },
            customer_id: springboard_user_id,
            billing_address_id: billing_address_id,
            shipping_address_id: shipping_address_id,
            shipping_charge: shipping_total(order),
            shipping_method_id: export_params_shipping_method_id(order),
            status: 'pending',
            sales_rep: sales_rep(order),
            source_location_id: source_location_id,
            station_id: SpreeSpringboard.configuration.station_id,
            created_at: order.completed_at,
            updated_at: order.updated_at
          }
        end

        def export_params_source_location_id(order)
          stock_location = order.shipments.map(&:stock_location).compact.find(&:springboard_id?)
          return if stock_location.blank?

          stock_location.springboard_id
        end

        def export_params_shipping_method_id(order)
          return if order.shipments.blank?

          shipping_methods = order.shipments.map(&:shipping_method).compact.uniq.select(&:springboard_id?)
          return if shipping_methods.blank?

          shipping_methods.first.springboard_id
        end

        def export_params_station_id(order)
          default_station_id = SpreeSpringboard.configuration.station_id
          return default_station_id if order.shipments.blank?

          stock_locations = order.shipments.map(&:stock_location).uniq.select(&:springboard_station_id?)
          return default_station_id if stock_locations.blank?

          stock_locations.first.springboard_station_id
        end

        def shipping_total(order)
          adjustments = order.shipments.map { |shipment| shipment.adjustments.eligible }.flatten
          order.ship_total + adjustments.sum(&:amount)
        end

        def sales_rep(_order)
          'Ecommerce'
        end

        def spree_taxes(order)
          order.adjustments.eligible.tax
        end

        def springboard_order_invoiceable?
          order.shipped? && order.springboard_element[:status] == 'open'
        end

        def springboard_invoice_params(order)
          {
            customer_id: prepare_springboard_user_id(order),
            order_id: order.springboard_id,
            source_location_id: export_params_source_location_id(order),
            station_id: export_params_station_id(order),
            total: order.total
          }
        end

        def springboard_invoice_line_params(line_item)
          {
            type: 'ItemLine',
            qty: line_item.springboard_element[:qty],
            item_id: line_item.springboard_element[:item_id]
          }
        end

        def springboard_invoiced?(order)
          order.child_springboard_id('invoice').present? && order.springboard_element[:status] == 'closed'
        end

        private

        def prepare_springboard_address_id(order, address_type, springboard_user_id)
          address = order.send(address_type)
          if order.user && address.user
            # Sync Spree address
            #   If order.user exists and order is placed on frontend, then address includes user_id
            #   If order is placed via backend, address doesn't include user_id
            address.prepare_springboard_id(parent: order)
          else
            # Check if guest address has already been synced
            springboard_id = order.child_springboard_id(address_type)
            return springboard_id if springboard_id.present?

            # Sync guest address if needed
            params = SpreeSpringboard::Resource::Export::Address.new.export_params(address)
            SpreeSpringboard::Resource::Export::Base.sync_parent!(
              "customers/#{springboard_user_id}/addresses", address_type, params, order
            )
          end
        end

        def prepare_springboard_user_id(order)
          if order.user
            # Sync Spree user
            order.user.prepare_springboard_id(first_name: order.bill_address.firstname, last_name: order.bill_address.lastname, parent: order)
          else
            # Check if guest user has already been synced
            springboard_id = order.child_springboard_id('user')
            return springboard_id if springboard_id.present?

            # Sync guest user if needed
            params = {
              first_name: order.bill_address.firstname,
              last_name: order.bill_address.lastname,
              email: order.email
            }
            SpreeSpringboard::Resource::Export::Base.sync_parent!(
              :customers, :user, params, order
            )
          end
        end
      end
    end
  end
end
