module SpreeSpringboard
  module Resource
    module Export
      class LineItem < SpreeSpringboard::Resource::Export::Base
        include SpreeSpringboard::Resource::Clients::LineItemClient

        def adjustments(line_item)
          line_item.order.adjustments.non_tax.where.not(source_type: 'Spree::Shipment')
        end

        def calculate_adjusted_unit_price(line_item)
          line_item.price + (discounts_amount(line_item) / line_item.quantity).round(2)
        end

        def calculate_total_tax(line_item)
          line_item.adjustments.tax.sum(:amount)
        end

        def export_params(line_item, _params = {})
          {
            adjusted_unit_price: calculate_adjusted_unit_price(line_item),
            item_id: variant_springboard_id(line_item),
            order_id: line_item.order.springboard_id,
            original_unit_price: line_item.price,
            qty: line_item.quantity,
            ship_from_location_id: ship_from_location_id(line_item),
            total_tax: calculate_total_tax(line_item),
            created_at: line_item.created_at,
            updated_at: line_item.updated_at,
            discounts: discounts(line_item)
          }
        end

        def discounts(line_item)
          discounts_per_line_item(line_item) + discounts_per_order(line_item)
        end

        def discounts_per_line_item(line_item)
          discounts = []
          if line_item.taxable_adjustment_total != 0
            discounts << { description: 'Line Item Adjustment', amount: line_item.taxable_adjustment_total }
          end
          discounts
        end

        def discounts_per_order(line_item)
          discounts = []
          order_adjustment_total = adjustments(line_item).sum(:amount)

          unless order_adjustment_total.zero?
            line_item_price_total = line_item.order.line_items.sum(:price)
            ratio = line_item.price / line_item_price_total
            discounts << {
              description: "Adjustments: #{adjustments(line_item).map(&:label).join(', ')}",
              amount: (ratio * order_adjustment_total).round(2)
            }
          end
          discounts
        end

        def discounts_amount(line_item)
          discounts(line_item).map { |discount| discount[:amount] }.sum
        end

        def ship_from_location_id(line_item)
          inventory_unit = line_item.inventory_units.find do |unit|
            shipment = unit.shipment
            if shipment.present?
              stock_location = shipment.stock_location
              stock_location.present? && stock_location.springboard_id?
            end
          end
          inventory_unit.shipment.stock_location.springboard_id if inventory_unit.present?
        end

        def variant_springboard_id(line_item)
          line_item.variant.springboard_id
        end
      end
    end
  end
end
