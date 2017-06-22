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

require 'roar/decorator'
require 'roar/json/hal'

module API
  module V3
    module Queries
      class QueryRepresenter < ::API::Decorators::Single
        self_link

        prepend QuerySerialization
        include API::Decorators::LinkedResource

        links :columns do
          represented.columns.map do |column|
            {
              href: api_v3_paths.query_column(convert_attribute(column.name)),
              title: column.caption
            }
          end
        end

        link :groupBy do
          column = represented.group_by_column

          if column
            {
              href: api_v3_paths.query_group_by(convert_attribute(column.name)),
              title: column.caption
            }
          else
            {
              href: nil,
              title: nil
            }
          end
        end

        #links :sortBy do
        #  map_with_sort_by_as_decorated(represented.sort_criteria_columns) do |sort_by|
        #    {
        #      href: api_v3_paths.query_sort_by(sort_by.converted_name, sort_by.direction_name),
        #      title: sort_by.name
        #    }
        #  end
        #end
        #linked_resource :sortBy,
        #                getter: ->(*) {
        #  binding.pry
        #                  map_with_sort_by_as_decorated(represented.sort_criteria_columns) do |sort_by|
        #                    {
        #                      href: api_v3_paths.query_sort_by(sort_by.converted_name, sort_by.direction_name),
        #                      title: sort_by.name
        #                    }
        #                  end
        #                },
        #                setter: ->(fragment:, **) {
        #                  binding.pry
        #                  set_sort_criteria(fragment)
        #                }

        linked_property :project #, title_getter: ->(*) { nil }

        property :name
        property :filters,
                 exec_context: :decorator#,
                 #render_filter: ->(input, options) { binding.pry;
                 #                                   input }# ,
                 #getter: ->(*) { trimmed_filters filters }

        property :display_sums, as: :sums
        property :is_public, as: :public

        # Timeline properties
        property :timeline_visible

        property :show_hierarchies

        property :timeline_zoom_level

        ##
        # Uses the normal query's filter representation and removes the bits
        # we don't want for a payload.
        def trimmed_filters(filters)
          filters.map(&:to_hash).map { |v| trim_links v }
        end

        def trim_links(value)
          if value.is_a? ::Hash
            ::Hash[value.except("_type", "name", "title", "schema").map { |k, v| [k, trim_links(v)] }]
          elsif value.is_a? Array
            value.map { |v| trim_links v }
          else
            value
          end
        end

        #prepend QuerySerialization
        #
        def to_hash(*)

          super
        end

        attr_accessor :results,
                      :params

        def initialize(model,
                       current_user:,
                       results: nil,
                       embed_links: false,
                       params: {})

          self.results = results
          self.params = params

          super(model, current_user: current_user, embed_links: embed_links)
        end

        link :results do
          path = if represented.project
                   api_v3_paths.work_packages_by_project(represented.project.id)
                 else
                   api_v3_paths.work_packages
                 end

          url_query = ::API::V3::Queries::QueryParamsRepresenter
                      .new(represented)
                      .to_h
                      .merge(params.slice(:offset, :pageSize))
          {
            href: [path, url_query.to_query].join('?')
          }
        end

        link :star do
          next if represented.starred || !allowed_to?(:star)

          {
            href: api_v3_paths.query_star(represented.id),
            method: :patch
          }
        end

        link :unstar do
          next unless represented.starred && allowed_to?(:unstar)

          {
            href: api_v3_paths.query_unstar(represented.id),
            method: :patch
          }
        end

        #links :columns do
        #  represented.columns.map do |column|
        #    {
        #      href: api_v3_paths.query_column(convert_attribute(column.name)),
        #      title: column.caption
        #    }
        #  end
        #end

        #link :groupBy do
        #  column = represented.group_by_column

        #  if column
        #    {
        #      href: api_v3_paths.query_group_by(convert_attribute(column.name)),
        #      title: column.caption
        #    }
        #  else
        #    {
        #      href: nil,
        #      title: nil
        #    }
        #  end
        #end

        #links :sortBy do
        #  map_with_sort_by_as_decorated(represented.sort_criteria_columns) do |sort_by|
        #    {
        #      href: api_v3_paths.query_sort_by(sort_by.converted_name, sort_by.direction_name),
        #      title: sort_by.name
        #    }
        #  end
        #end

        link :schema do
          href = if represented.project
                   api_v3_paths.query_project_schema(represented.project.identifier)
                 else
                   api_v3_paths.query_schema
                 end
          {
            href: href
          }
        end

        link :update do
          href = if represented.new_record?
                   api_v3_paths.create_query_form
                 else
                   api_v3_paths.query_form(represented.id)
                 end

          {
            href: href,
            method: :post
          }
        end

        link :updateImmediately do
          next unless represented.new_record? && allowed_to?(:create) ||
                      represented.persisted? && allowed_to?(:update)
          {
            href: api_v3_paths.query(represented.id),
            method: :patch
          }
        end

        link :delete do
          next if represented.new_record? ||
                  !allowed_to?(:destroy)

          {
            href: api_v3_paths.query(represented.id),
            method: :delete
          }
        end

        linked_property :user
        #linked_property :project

        property :id,
         # skip_render: ->(options) { options[:decorator].payload? && !options[:binding][:writeable] },
                 writeable: false
        #property :name
        #property :filters, exec_context: :decorator

        #property :is_public, as: :public

        #property :sort_by_embedded,
        #         as: :sortBy,
        #         exec_context: :decorator,
        #         embedded: true,
        #         if: ->(*) {
        #           embed_links
        #         }
        resources :sortBy,
                  getter: ->(*) {
                    sort_by
                  },
                  setter: ->(fragment:, **) {
                    set_sort_criteria(fragment)
                  },
                  link: ->(*) {
                    map_with_sort_by_as_decorated(represented.sort_criteria_columns) do |sort_by|
                      {
                        href: api_v3_paths.query_sort_by(sort_by.converted_name, sort_by.direction_name),
                        title: sort_by.name
                      }
                    end
                  },
                  show_if: ->(*) {
                    embed_links
                  }

        #linked_resource :sortBy,
        #                getter: ->(*) {
        #  binding.pry
        #                  map_with_sort_by_as_decorated(represented.sort_criteria_columns) do |sort_by|
        #                    {
        #                      href: api_v3_paths.query_sort_by(sort_by.converted_name, sort_by.direction_name),
        #                      title: sort_by.name
        #                    }
        #                  end
        #                },
        #                setter: ->(fragment:, **) {
        #                  binding.pry
        #                  set_sort_criteria(fragment)
        #                }

        #property :display_sums,
        #         as: :sums

        #property :timeline_visible

        #property :show_hierarchies

        property :starred

        property :columns,
                 exec_context: :decorator,
                 embedded: true,
                 if: ->(*) {
                   embed_links
                 }

        property :group_by,
                 exec_context: :decorator,
                 embedded: true,
                 if: ->(*) {
                   embed_links
                 },
                 render_nil: true

        property :results,
                 exec_context: :decorator,
                 render_nil: true,
                 embedded: true,
                 if: ->(*) {
                   results
                 }

        self.to_eager_load = [:query_menu_item,
                              :user,
                              project: :work_package_custom_fields]

        def _type
          'Query'
        end

        def filters
          represented.filters.map do |filter|
            ::API::V3::Queries::Filters::QueryFilterInstanceRepresenter
              .new(filter)
          end
        end

        def filters=(filters_hash)
          represented.filters = []

          filters_hash.each do |filter_attributes|
            name = get_filter_name filter_attributes

            filter = represented.filter_for name
            if filter
              filter_representer = ::API::V3::Queries::Filters::QueryFilterInstanceRepresenter.new(filter)

              filter = filter_representer.from_hash filter_attributes
              represented.filters << filter
            else
              raise API::Errors::InvalidRequestBody, "Could not read filter from: #{filter_attributes}"
            end
          end
        end

        private

        def allowed_to?(action)
          @policy ||= QueryPolicy.new(current_user)

          @policy.allowed?(represented, action)
        end

        def self_v3_path(*_args)
          if represented.new_record? && represented.project
            api_v3_paths.query_project_default(represented.project.id)
          elsif represented.new_record?
            api_v3_paths.query_default
          else
            super
          end
        end
      end
    end
  end
end
