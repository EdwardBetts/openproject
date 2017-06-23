module API
  module Utilities
    module PayloadRepresenter
      def representable_attrs
        super.dup.reject! do |_key, binding|
          binding[:writeable] == false
        end
      end

      def representable_map(*)
        writeable = super.dup.reject! do |binding|
          binding[:writeable] == false
        end

        writeable.each do |binding|
          binding[:render_filter] << nested_payload_block
        end
        links = writeable.detect { |binding| binding.name == 'links' }

        links[:render_filter] << link_render_block

        writeable
      end

      def link_render_block
        ->(input, _options) {
          input.reject do |link|
            link.rel && !representable_attrs[link.rel.to_s]
          end
        }
      end

      def nested_payload_block
        ->(input, _options) {
          if input.is_a?(::API::Decorators::Single)
            input.extend(::API::Utilities::PayloadRepresenter)
          elsif input.is_a?(Array) && input.all? { |rep| rep.is_a? ::API::Decorators::Single }
            input.each { |rep| rep.extend ::API::Utilities::PayloadRepresenter }
          else
            input
          end
        }
      end
    end
  end
end
