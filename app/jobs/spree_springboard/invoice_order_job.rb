module SpreeSpringboard
  class InvoiceOrderJob < ApplicationJob
    queue_as :springboard

    def perform(order_id)
      order = Spree::Order.find(order_id)

      if order.shipments.all?(&:shipped?)
        order.springboard_export! if order.springboard_id.nil?
        order.springboard_invoice!
      end
    rescue StandardError => e
      Raven.extra_context(order_number: order.number)

      raise e
    end
  end
end
