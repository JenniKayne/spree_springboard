module SpreeSpringboard
  module Resource
    module Import
      class Variant < SpreeSpringboard::Resource::Import::Base
        #
        # Product / Variant creation methods
        #
        module Create
          NAMES = {
            taxonomy: 'Color',
            size: 'Size',
            season: 'Season',
            product_line: 'Product line',
            description: 'Short description',
            tax_category: 'Default',
            shipping_category: 'Default'
          }.freeze

          #
          # Perform variant import of one page of springboard_items
          #
          def import_page(import_client, page_no)
            response = import_client.query(per_page: PER_PAGE, page: page_no).get
            return unless response.success?

            import_springboard_resources(response.body.results)
          end

          #
          # Perform variant import of the given collection of springboard_items
          #
          def import_springboard_resources(springboard_items)
            springboard_items.each do |springboard_item|
              begin
                next if springboard_item.custom.style_name.blank? ||
                    springboard_item.custom.style_code.blank? ||
                    springboard_item.custom[:size].blank?

                product = find_or_create_product(springboard_item)
                # Create new variant for product
                create_variant(product, springboard_item)
              rescue StandardError => error
                log(error, exception_report_params(springboard_resource))
                next
              end  
            end
          end

          def find_or_create_product(item)
            sku = prepare_sku(item.custom)

            # Find master variant
            master_variant = Spree::Variant.find_by(sku: sku)
            return master_variant.product unless master_variant.nil?

            # Create new product with master variant if none exists
            shipping_category = Spree::ShippingCategory.find_or_create_by(name: NAMES[:shipping_category])
            tax_category = Spree::TaxCategory.find_or_create_by(name: NAMES[:tax_category])
            option_types = Spree::OptionType.where(name: NAMES[:size])
            create_taxonomy(item.custom.color, NAMES[:taxonomy])
            taxons = Spree::Taxon.where(name: item.custom.color)

            product = Spree::Product.create!(
              available_on: nil,
              cost_price: item.cost,
              depth: item.depth,
              description: item.long_description,
              height: item.height,
              name: item.custom.style_name,
              option_types: option_types,
              original_price: item.original_price,
              sale_price: item.price,
              shipping_category: shipping_category,
              sku: sku,
              style_code: item.custom.style_code,
              tax_category: tax_category,
              taxons: taxons,
              weight: item.weight,
              width: item.width
            )
            set_product_property(product, item.custom.product_line1, NAMES[:product_line])
            set_product_property(product, item.custom.season, NAMES[:season])
            set_product_property(product, item.description, NAMES[:description])

            product
          end

          def create_variant(product, item)
            return if Spree::Variant.exists?(sku: item.public_id)

            create_option_value(item.custom[:size], NAMES[:size])
            new_variant(item, product)
          end

          def new_variant(item, product)
            option_values = Spree::OptionValue.where(name: item.custom[:size])
            variant = Spree::Variant.create!(
              cost_price: item.cost,
              depth: item.depth,
              height: item.height,
              option_values: option_values,
              original_price: item.original_price,
              sale_price: item.price,
              product: product,
              sku: item.public_id,
              upc: item.custom.upc,
              weight: item.weight,
              width: item.width
            )
            variant.springboard_id = item.id
            variant
          end

          #
          # Helper methods
          #
          def create_option_type(name)
            Spree::OptionType.find_or_create_by(name: name, presentation: name)
          end

          def create_option_value(value, option_name)
            return if value.blank?
            option_type = Spree::OptionType.find_by(name: option_name)
            return unless option_type
            Spree::OptionValue.find_or_create_by(name: value, presentation: value, option_type: option_type)
          end

          def create_property(name)
            Spree::Property.find_or_create_by(name: name, presentation: name)
          end

          def create_product_property(product, property, value)
            Spree::ProductProperty.create(product: product, property: property, value: value)
          end

          def create_taxon(taxonomy, value)
            Spree::Taxon.find_or_create_by(parent: taxonomy.taxons.root, taxonomy: taxonomy, name: value)
          end

          def create_taxonomy(value, taxonomy_name)
            return if value.blank?
            taxonomy = Spree::Taxonomy.find_or_create_by(name: taxonomy_name)
            return unless taxonomy
            create_taxon(taxonomy, value)
          end

          def prepare_sku(custom)
            custom.color.blank? ? custom.style_code : "#{custom.style_code}-#{custom.color.split(' ').join('-')}"
          end

          def set_product_property(product, value, property_name)
            return if value.blank?
            property = Spree::Property.find_by(name: property_name)
            return unless property
            create_product_property(product, property, value)
          end
        end
      end
    end
  end
end
