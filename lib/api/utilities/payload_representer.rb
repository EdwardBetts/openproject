#-- encoding: UTF-8

#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2017 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module API
  module Utilities
    module PayloadRepresenter
      def to_hash(*)
        writeable_attr = writeable_attributes(represented)

        representable_attrs.each do |property|
          property[:render_filter] << nested_payload_block

          as = property[:as].()

          if property.name == 'links'
            property[:render_filter] << link_render_block
          elsif !writeable_attr.include?(as) || property[:writeable] == false
            property.merge!(readable: false)
          end
        end

        super
      end

      def link_render_block
        ->(input, _options) do
          writeable_attr = writeable_attributes(represented)

          input.reject do |link|
            link.rel && !writeable_attr.include?(link.rel.to_s)
          end
        end
      end

      def nested_payload_block
        ->(input, _options) do
          if input.is_a?(::API::Decorators::Single)
            input.extend(::API::Utilities::PayloadRepresenter)
          elsif input.is_a?(Array) && input.all? { |rep| rep.is_a? ::API::Decorators::Single }
            input.each { |rep| rep.extend ::API::Utilities::PayloadRepresenter }
          else
            input
          end
        end
      end

      def contract?(represented)
        contract_name(represented).present?
      end

      def writeable_attributes(represented)
        contract = contract_name(represented)

        if contract
          contract
            .constantize
            .new(represented, current_user: current_user)
            .writable_attributes
            .map { |name| ::API::Utilities::PropertyNameConverter.from_ar_name(name) }
        else
          representable_attrs.map do |property|
            property[:as].()
          end
        end
      end

      private

      def contract_name(represented)
        return nil unless represented

        contract_namespace = represented.class.name.pluralize

        return nil unless Object.const_defined?(contract_namespace)

        contract_name = if represented.new_record?
                          "CreateContract"
                        else
                          "UpdateContract"
                        end

        return nil unless contract_namespace.constantize.const_defined?(contract_name)

        "#{contract_namespace}::#{contract_name}"
      end
    end
  end
end
