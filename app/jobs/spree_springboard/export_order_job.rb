module SpreeSpringboard
  class ExportOrderJob < ApplicationJob
    queue_as :springboard

    def perform(order_id)
      order = Spree::Order.find(order_id)

      order.springboard_export! if order.springboard_id.blank?
    rescue StandardError => e
      Raven.extra_context(order_number: order.number)

      raise e
    end
  end
end
