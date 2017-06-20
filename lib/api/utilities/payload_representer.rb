module API
  module Utilities
    module PayloadRepresenter
      #def self.included(base)
      #  base.extend(ClassMethods)
      #end

      def to_hash(*)
        hash = super

        hash
      end

      def representable_attrs
        super.dup.reject! do |key, binding|
          binding[:writeable] == false
        end
      end

      def representable_map(*)
        binding.pry
        super.dup.reject! do |binding|
          binding[:writeable] == false
        end.each do |binding|
          binding[:render_filter] << nested_payload_block
        end
      end

      def nested_payload_block
        ->(input, options) {
          if input.is_a?(::API::Decorators::Single)
            input.extend(::API::Utilities::PayloadRepresenter)
          elsif input.is_a?(Array) && input.all? { |rep| rep.is_a? ::API::Decorators::Single }
            input.each { |rep| rep.extend ::API::Utilities::PayloadRepresenter }
          elsif options[:binding].name == 'links'
            []
          else
            input
          end
        }
      end
    end
  end
end
