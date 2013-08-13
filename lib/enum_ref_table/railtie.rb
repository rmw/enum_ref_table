module EnumRefTable
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :enum_ref_table do
        task :load_schema_dumper do
          require 'enum_ref_table/schema_dumper'
        end

        task :allow_missing_tables do
          EnumRefTable.missing_tables_allowed
        end
      end

      Rake::Task['db:schema:dump'].prerequisites << 'enum_ref_table:load_schema_dumper'

      %w'db:schema:load db:migrate db:migrate:up'.each do |task|
        task = Rake::Task[task]
        task.prerequisites.insert 0, 'enum_ref_table:allow_missing_tables'
        task.enhance { EnumRefTable.missing_tables_disallowed }
      end
    end
  end
end
