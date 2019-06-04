module SpreeSpringboard
  module Resource
    class Base
      attr_reader :errors

      def client(_resource)
        raise 'Implement `client` for each resource'
      end

      def client_resource(_resource)
        raise 'Implement `client_resource` for each resource'
      end

      def initialize
        @errors = []
      end

      #
      # Log handler
      #
      def log(error, params)
        Raven.extra_context(params)
        Raven.capture_exception(error)
      end
    end
  end
end
