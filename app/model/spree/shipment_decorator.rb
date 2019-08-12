module Spree
  Shipment.class_eval do
    # state_machine do
    #   after_transition to: :shipped, do: :springboard_after_ship
    # end

    # Schedule to create an invoice in Springboard (after shipment has been shipped)
    def springboard_after_ship
      SpreeSpringboard::InvoiceOrderJob.perform_later(order.id)
    end
  end
end
