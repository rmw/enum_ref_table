module EnumRefTable
  module Record
    extend ActiveSupport::Concern

    included do
      class_attribute :enum_refs
      self.enum_refs = {}
    end

    module ClassMethods
      def enum_ref(name, options={})
        name = name.to_sym
        reflection = enum_refs[name] ? enum_refs[name].dup : Reflection.new(name)
        [:type, :id_name].each do |key|
          value = options[key] and
            reflection.send "#{key}=", value
        end
        enum_ref_map(name, options).each do |value, id|
          reflection.add_value id, value
        end
        self.enum_refs = enum_refs.merge(name => reflection, name.to_s => reflection)

        class_eval <<-EOS, __FILE__, __LINE__ + 1
          def #{name}
            read_enum_ref(:#{name})
          end

          def #{name}=(value)
            write_enum_ref(:#{name}, value)
          end

          def #{name}?
            query_enum_ref(:#{name})
          end

          def #{name}_changed?
            enum_ref_changed?(:#{name})
          end

          def #{name}_was
            enum_ref_was(:#{name})
          end

          def #{name}_change
            enum_ref_change(:#{name})
          end
        EOS

        reflection
      end

      def enum_ref_map(name, options)
        case (table = options[:table])
        when Hash
          table
        when Array
          map = {}
          table.each_with_index { |element, i| map[element] = i + 1 }
          map
        when String, Symbol, nil
          map = {}
          table_name = table || "#{self.table_name.singularize}_#{name.to_s.pluralize}"
          return {} if EnumRefTable.missing_tables_allowed? && !connection.tables.include?(table_name)
          connection.execute("SELECT id, value FROM #{connection.quote_table_name table_name}").each do |row|
            map[row[1]] = row[0]
          end
          map
        else
          raise ArgumentError, "invalid table specifier: #{table.inspect}"
        end
      end

      def reflect_on_enum_ref(name)
        enum_refs[name]
      end

      def enum_ref_id(name, value)
        reflection = enum_refs[name] or
          raise ArgumentError, "no such enum_ref: #{name}"
        reflection.id(value)
      end

      # Enables enum_refs for STI types.
      def builtin_inheritance_column  # :nodoc:
        # Can this be made less brittle?
        if self == ActiveRecord::Base
          'type'
        else
          (@builtin_inheritance_column ||= nil) || superclass.builtin_inheritance_column
        end
      end

      def inheritance_enum_ref  # :nodoc:
        @inheritance_enum_ref ||= enum_refs[builtin_inheritance_column.to_sym]
      end

      def inheritance_column  # :nodoc:
        (reflection = inheritance_enum_ref) ? reflection.id_name.to_s : super
      end

      def sti_name  # :nodoc:
        (reflection = inheritance_enum_ref) ? reflection.id(super) : super
      end

      def find_sti_class(type_name)  # :nodoc:
        (reflection = inheritance_enum_ref) ? super(reflection.value(type_name).to_s) : super
      end

      # Enables .find_by_name(value) for enum_refs.
      def expand_hash_conditions_for_aggregates(attrs)  # :nodoc:
        conditions = super
        enum_refs.each do |name, reflection|
          if conditions.key?(name)
            value = conditions.delete(name)
          elsif conditions.key?((string_name = name.to_s))
            value = conditions.delete(string_name)
          else
            next
          end
          if value.is_a?(Array)
            id = value.map { |el| reflection.id(el) }
          else
            id = reflection.id(value)
          end
          conditions[reflection.id_name] = id
        end
        conditions
      end

      # Enables .where(name: value) for enum_refs.
      def expand_attribute_names_for_aggregates(attribute_names)  # :nodoc:
        attribute_names = super
        enum_refs.each do |name, reflection|
          index = attribute_names.index(name) and
            attribute_names[index] = reflection.id_name
        end
        attribute_names
      end

      # Enables state_machine to set initial values for states. Ick.
      def initialize_attributes(attributes)  # :nodoc:
        attributes = super
        enum_refs.each do |name, reflection|
          if (value = attributes.delete(reflection.name.to_s))
            attributes[reflection.id_name.to_s] ||= reflection.id(value)
          end
        end
        attributes
      end
    end

    def enum_ref(name)
      self.class.enum_refs[name]
    end

    def enum_ref!(name)
      self.class.enum_refs[name] or
        raise ArgumentError, "no such enum_ref: #{name}"
    end

    def enum_ref_id(name, value)
      self.class.enum_ref_id(name, value)
    end

    def read_enum_ref(name)
      reflection = enum_ref!(name)
      id = read_attribute(reflection.id_name)
      reflection.value(id)
    end

    def query_enum_ref(name)
      reflection = enum_ref!(name)
      id = read_attribute(reflection.id_name)
      !!reflection.value(id)
    end

    def write_enum_ref(name, value)
      reflection = enum_ref!(name)
      id = reflection.id(value)
      write_attribute(reflection.id_name, id)
      value
    end

    def enum_ref_changed?(name)
      reflection = enum_ref!(name)
      attribute_changed?(reflection.id_name.to_s)
    end

    def enum_ref_was(name)
      reflection = enum_ref!(name)
      id = attribute_was(reflection.id_name.to_s)
      reflection.value(id)
    end

    def enum_ref_change(name)
      reflection = enum_ref!(name)
      change = attribute_change(reflection.id_name.to_s) or
        return nil
      old_id, new_id = *change
      [reflection.value(old_id), reflection.value(new_id)]
    end

    def read_attribute(name)
      reflection = enum_ref(name) or
        return super
      read_enum_ref(name)
    end

    def write_attribute(name, value)
      reflection = enum_ref(name) or
        return super
      write_enum_ref(name, value)
    end
  end
end
