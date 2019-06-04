module SpreeSpringboard
  class ExportOrderJob < ApplicationJob
    queue_as :springboard

    def perform(order)
      order.springboard_export! if order.springboard_id.blank?
    rescue StandardError => error
      Raven.extra_context(order_number: order.number)

      raise error
    end
  end
end
