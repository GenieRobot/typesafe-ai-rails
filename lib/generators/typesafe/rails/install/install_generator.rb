# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Typesafe
  module Rails
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        include ::Rails::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        desc "Installs or upgrades TypeSafe AI Rails integration tables and configuration."

        def self.next_migration_number(dirname)
          ::ActiveRecord::Generators::Base.next_migration_number(dirname)
        end

        def create_migration_files
          if migration_exists?("create_typesafe_rails_tables")
            unless migration_exists?("upgrade_typesafe_rails_to_0_4")
              migration_template(
                "upgrade_typesafe_rails_to_0_4.rb.tt",
                "db/migrate/upgrade_typesafe_rails_to_0_4.rb"
              )
            end
          else
            migration_template(
              "create_typesafe_rails_tables.rb.tt",
              "db/migrate/create_typesafe_rails_tables.rb"
            )
          end
        end

        def add_initializer
          template "typesafe.rb.tt", "config/initializers/typesafe.rb"
        end

        def show_readme
          readme "POST_INSTALL.md" if behavior == :invoke
        end

        private

        def migration_exists?(basename)
          Dir.glob(File.join(destination_root, "db/migrate/*_#{basename}.rb")).any?
        end
      end
    end
  end
end
