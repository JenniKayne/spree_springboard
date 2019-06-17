class AddResourceExportParamsToSpringboardLog < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_springboard_logs, :resource_export_params, :json, default: nil
  end
end
