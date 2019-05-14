module SpreeSpringboard
  class ImportReturnsJob < ApplicationJob
    queue_as :springboard

    def perform
      Spree::ReturnAuthorization.springboard_import_last_day!
    end
  end
end
