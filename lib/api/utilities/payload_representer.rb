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

        if links
          links[:render_filter] << link_render_block
        end

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
