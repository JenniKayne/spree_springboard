module SpreeSpringboard
  module Resource
    module Import
      class Variant < SpreeSpringboard::Resource::Import::Base
        include SpreeSpringboard::Resource::Clients::VariantClient
        self.spree_class = Spree::Variant

        PER_PAGE = 1000

        include SpreeSpringboard::Resource::Import::Variant::Create
        include SpreeSpringboard::Resource::Import::Variant::Update

        def import_all_perform(import_client)
          create_property(NAMES[:product_line])
          create_option_type(NAMES[:size])

          prepare_data
          page_count = springboard_page_count(import_client)
          page_count.downto(1).each do |page_no|
            import_page(import_client, page_no)
          end

          true
        end

        #
        # Fetch product page count
        #
        def springboard_page_count(import_client)
          import_client.query(per_page: PER_PAGE).filter(active: true).get.body.pages
        end
      end
    end
  end
end
