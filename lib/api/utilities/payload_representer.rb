module API
  module Utilities
    module PayloadRepresenter
      #def self.included(base)
      #  base.extend(ClassMethods)
      #end

      #def to_hash(*)
      #  hash = super

      #  hash
      #end

      def representable_attrs
        super.dup.reject! do |key, binding|
          binding[:writeable] == false
        end
        #binding.pry
        #super

        # Versuchen eine gemeinsame property zu definieren die:
        #  * Einen setter hat der über links funktioniert
        #  * einen getter der für das embedden zuständig ist
        #  * einen link der eine link definition erzeugt
        #  * writeable: true setzt
        #
        # Dann die links entfernen, die nicht writeable gesetzt haben
      end

      def representable_map(*)
        #binding.pry
        #x = super

        #links = x.detect { |binding| binding.name == 'links' }

        #links[:render_filter] << link_render_block

        #x
        writeable = super.dup.reject! do |binding|
          binding[:writeable] == false
        end

        writeable.each do |binding|
          binding[:render_filter] << nested_payload_block
        end
      end

      #def link_render_block
      #  ->(input, options) {
      #    binding.pry

      #    input



      #  }
      #end

      #  writeable = super.dup.reject! do |binding|
      #    binding[:writeable] == false
      #  end

      #  writeable.each do |binding|
      #    binding[:render_filter] << nested_payload_block
      #  end
      #end

      def nested_payload_block
        ->(input, options) {
          if input.is_a?(::API::Decorators::Single)
            input.extend(::API::Utilities::PayloadRepresenter)
          elsif input.is_a?(Array) && input.all? { |rep| rep.is_a? ::API::Decorators::Single }
            input.each { |rep| rep.extend ::API::Utilities::PayloadRepresenter }
          #elsif options[:binding].name == 'links'
          #  []
       #    links[:render_filter] << link_render_block
          else
           input
          end
        }
      end
    end
  end
end
