module EnumRefTable
  autoload :VERSION, 'enum_ref_table/version'
  autoload :Record, 'enum_ref_table/record'
  autoload :Reflection, 'enum_ref_table/reflection'
  autoload :SchemaDumper, 'enum_ref_table/schema_dumper'
  autoload :SchemaStatements, 'enum_ref_table/schema_statements'

  # Allow enum tables to be missing until missing_tables_disallowed is
  # called. This is invoked from rake tasks that create the enum tables, such as
  # Rails migration tasks.
  #
  # Missing table allowance is implemented as a thread-local stack to handle
  # nested invocations in multi-threaded programs.
  class << self
    def missing_tables_allowed
      missing_tables_allowances.push true
    end

    def missing_tables_disallowed
      missing_tables_allowances.pop
    end

    def missing_tables_allowed?
      !missing_tables_allowances.empty?
    end

    # Reset our state. Intended for testing Enum Table.
    def reset
      Thread.current[:enum_ref_table_missing_tables_allowed] = nil
    end

    private

    def missing_tables_allowances
      Thread.current[:enum_ref_table_missing_tables_allowed] ||= []
    end
  end
end

require 'enum_ref_table/railtie' if defined?(Rails)
ActiveRecord::Base.send :include, EnumRefTable::Record
ActiveRecord::ConnectionAdapters::AbstractAdapter.send :include, EnumRefTable::SchemaStatements
