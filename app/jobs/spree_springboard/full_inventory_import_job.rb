module SpreeSpringboard
  class FullInventoryImportJob < ApplicationJob
    queue_as :springboard

    def perform
      job = SpreeSpringboard::InventoryImport::Full.new
      job.perform
    rescue StandardError => error
      Raven.capture_exception(error)
    ensure
      job.unlock if job.in_progress?
    end
  end
end
