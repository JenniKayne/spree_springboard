module SpreeSpringboard::Resource::Clients
  module AdjustmentClient
    def client(adjustment)
      raise 'Sync adjustment.order first' unless adjustment.order.springboard_id.present?
      client_create(adjustment)
    end

    def client_create(adjustment)
      if SpreeSpringboard::Resource::Export::Adjustment.adjustment_type(adjustment) == 'tax'
        client_create_tax(adjustment)
      else
        client_create_discount(adjustment)
      end
    end

    def client_create_tax(adjustment)
      order_springboard_id = adjustment.order.springboard_id
      SpreeSpringboard.client["sales/orders/#{order_springboard_id}/taxes"]
    end

    def client_create_discount(adjustment)
      order_springboard_id = adjustment.order.springboard_id
      SpreeSpringboard.client["sales/orders/#{order_springboard_id}/lines"]
    end
  end
end
