module Spree
  class SpringboardLog < Spree::Base
    belongs_to :resource, polymorphic: true
    belongs_to :parent, polymorphic: true

    scope :error_type, -> { where(message_type: :error) }
    scope :success_type, -> { where(message_type: :success) }
    scope :notice_type, -> { where(message_type: :notice) }

    self.whitelisted_ransackable_attributes = %w[
      created_at
      transaction_id
      resource_type
      resource_id
      parent_type
      parent_id
    ]

    def self.error(message, resource = nil, params = {})
      create_log(:error, message, resource, params)
    end

    def self.notice(message, resource = nil, params = {})
      create_log(:notice, message, resource, params)
    end

    def self.success(message, resource = nil, params = {})
      create_log(:success, message, resource, params)
    end

    def self.create_log(message_type, message, resource = nil, params = {})
      log_params = params.merge(
        message: message,
        message_type: message_type,
        resource: resource,
      )

      # Make sure there is no resource: nil in hash - it overrides resource_type: value
      log_params.delete(:resource) if log_params[:resource].nil?
      # Make sure there is no resource_export_params: nil in hash
      log_params.delete(:resource_export_params) if log_params[:resource_export_params].nil?
      create! log_params
    end
  end
end
