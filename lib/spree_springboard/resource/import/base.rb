module SpreeSpringboard
  module Resource
    module Import
      class Base < SpreeSpringboard::Resource::Base
        class_attribute :spree_class

        def create_from_springboard_resource(_springboard_resource)
          raise 'Implement create_from_springboard_resource method for each resource'
        end

        def exception_report_params(springboard_resource)
          {
            data: {
              msg: "Import #{spree_class.name.demodulize.titleize.pluralize}",
              springboard_resource: springboard_resource
            }
          }
        end

        def find_spree_resource(springboard_resource)
          spree_class.find_springboard_synced(springboard_resource[:id])
        end

        #
        # Import all Springboard items
        #
        def import_all!
          return if spree_class.nil?
          import_all_perform(client_query)
        end

        #
        # Perform Springboard import using the selected query client
        #
        def import_all_perform(import_client)
          springboard_resources = import_client.get.body.results
          import_springboard_resources(springboard_resources)
          true
        end

        #
        # Import Spree Elements from Springboard Resources
        #
        def import_springboard_resources(springboard_resources)
          springboard_resources.each do |springboard_resource|
            begin
              if find_spree_resource(springboard_resource).blank?
                create_from_springboard_resource(springboard_resource)
              end
            rescue StandardError => error
              log(error, exception_report_params(springboard_resource))
              next
            end
          end
          true
        end
      end
    end
  end
end
