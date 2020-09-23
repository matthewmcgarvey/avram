class Avram::SaveOperationTemplate
  macro setup(type)
    class ::{{ type }}::BaseForm
      macro inherited
        \{% raise "BaseForm has been renamed to SaveOperation. Please inherit from {{ type }}::SaveOperation." %}
      end
    end

    # This makes it easy for plugins and extensions to use the base SaveOperation
    def base_query_class : ::{{ type }}::BaseQuery.class
      ::{{ type }}::BaseQuery
    end

    def save_operation_class : ::{{ type }}::SaveOperation.class
      ::{{ type }}::SaveOperation
    end

    class ::{{ type }}::SaveOperation < Avram::SaveOperation({{ type }})
      {% if type.resolve.constant("PRIMARY_KEY_TYPE").id == UUID.id %}
        before_save set_uuid

        def set_uuid
          {{ type.resolve.constant("PRIMARY_KEY_NAME").id }}.value ||= UUID.random()
        end
      {% end %}

      def database
        {{ type }}.database
      end

      macro inherited
        FOREIGN_KEY = "{{ type.stringify.underscore.id }}_id"
      end

      def table_name : Symbol
        {{ type }}.table_name
      end

      def primary_key_name
        {{ type }}.primary_key_name
      end

      add_column_attributes({{ type.resolve.constant("COLUMNS") }})
      add_cast_value_methods({{ type.resolve.constant("COLUMNS") }})
    end
  end
end
