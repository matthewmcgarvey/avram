require "db"
require "levenshtein"
require "./schema_enforcer"
require "./polymorphic"

abstract class Avram::Model
  include Avram::Associations
  include Avram::Polymorphic
  include Avram::SchemaEnforcer

  SETUP_STEPS = [] of Nil # types are not checked in macros
  # This setting is used to show better errors
  MACRO_CHECKS = {setup_complete: false}

  class_getter table_name

  abstract def id

  macro register_setup_step(call)
    {% if MACRO_CHECKS[:setup_complete] %}
      {% call.raise "Models have already been set up. Make sure to register set up steps before models are required." %}
    {% else %}
      {% SETUP_STEPS << call %}
    {% end %}
  end

  register_setup_step Avram::Model.setup_initialize
  register_setup_step Avram::Model.setup_getters
  register_setup_step Avram::Model.setup_column_names_method
  register_setup_step Avram::BaseQueryTemplate.setup
  register_setup_step Avram::SaveOperationTemplate.setup
  register_setup_step Avram::SchemaEnforcer.setup

  macro inherited
    include DB::Serializable

    COLUMNS = [] of Nil # types are not checked in macros
    ASSOCIATIONS = [] of Nil # types are not checked in macros
  end

  def_equals id, model_name

  def model_name
    self.class.name
  end

  def to_param
    id.to_s
  end

  # Reload the model with the latest information from the database
  #
  # This method will return a new model instance with the
  # latest data from the database. Note that this does
  # **not** change the original instance, so you may need to
  # assign the result to a variable or work directly with the return value.
  #
  # Example:
  #
  # ```crystal
  # user = SaveUser.create!(name: "Original")
  # SaveUser.update!(user, name: "Updated")
  #
  # # Will be "Original"
  # user.name
  # # Will return "Updated"
  # user.reload.name # Will be "Updated"
  # # Will still be "Original" since the 'user' is the same model instance.
  # user.name
  #
  # Instead re-assign the variable. Now 'name' will return "Updated" since
  # 'user' references the reloaded model.
  # user = user.reload
  # user.name
  # ```
  def reload : self
    base_query_class.find(id)
  end

  # Same as `reload` but allows passing a block to customize the query.
  #
  # This is almost always used to preload additional relationships.
  #
  # Example:
  #
  # ```crystal
  # user = SaveUser.create(params)
  #
  # # We want to display the list of articles the user has commented on, so let's #
  # # preload them to avoid N+1 performance issues
  # user = user.reload(&.preload_comments(CommentQuery.new.preload_article))
  #
  # # Now we can safely get all the comment authors
  # user.comments.map(&.article)
  # ```
  #
  # Note that the yielded query is the `BaseQuery` so it will not have any
  # methods defined on your customized query. This is usually fine since
  # typically reload only uses preloads.
  #
  # If you do need to do something more custom you can manually reload:
  #
  # ```crystal
  # user = SaveUser.create!(name: "Helen")
  # UserQuery.new.some_custom_preload_method.find(user.id)
  # ```
  def reload : self
    query = yield base_query_class.new
    query.find(id)
  end

  macro table(table_name = nil)
    {% unless table_name %}
      {% table_name = run("../run_macros/infer_table_name.cr", @type.id) %}
    {% end %}
    TABLE_NAME = {{table_name.id.symbolize}}
    @@table_name = TABLE_NAME

    default_columns

    {{ yield }}

    validate_primary_key

    setup({{table_name}})
    {% MACRO_CHECKS[:setup_complete] = true %}
  end

  macro primary_key(type_declaration)
    PRIMARY_KEY_TYPE = {{ type_declaration.type }}
    PRIMARY_KEY_NAME = {{ type_declaration.var.symbolize }}
    column {{ type_declaration.var }} : {{ type_declaration.type }}, autogenerated: true
    alias PrimaryKeyType = {{ type_declaration.type }}

    def self.primary_key_name : Symbol
      {{ type_declaration.var.symbolize }}
    end

    def primary_key_name : Symbol
      self.class.primary_key_name
    end

    # If not using default 'id' primary key
    {% if type_declaration.var.id != "id".id %}
      # Then point 'id' to the primary key
      def id
        {{ type_declaration.var.id }}
      end
    {% end %}
  end

  macro validate_primary_key
    {% if !@type.has_constant? "PRIMARY_KEY_TYPE" %}
      \{% raise <<-ERROR
        No primary key was specified.

        Example:

          table do
            primary_key id : Int64
            ...
          end
        ERROR
      %}
    {% end %}
  end

  macro default_columns
    primary_key id : Int64
    timestamps
  end

  macro skip_default_columns
    macro default_columns
    end
  end

  macro timestamps
    column created_at : Time, autogenerated: true
    column updated_at : Time, autogenerated: true
  end

  macro setup(table_name)
    {% table_name = table_name.id %}

    {% for step in SETUP_STEPS %}
      {{ step.id }}(
        type: {{ @type }},
        table_name: {{ table_name }},
        primary_key_type: {{ PRIMARY_KEY_TYPE }},
        primary_key_name: {{ PRIMARY_KEY_NAME }},
        columns: {{ COLUMNS }},
        associations: {{ ASSOCIATIONS }}
      )
    {% end %}
  end

  def delete
    self.class.database.exec "DELETE FROM #{@@table_name} WHERE #{primary_key_name} = #{escape_primary_key(id)}"
  end

  private def escape_primary_key(id : Int64 | Int32 | Int16)
    id
  end

  private def escape_primary_key(id : UUID)
    PG::EscapeHelper.escape_literal(id.to_s)
  end

  macro setup_initialize(type, *args, **named_args)
    def initialize(
        {% for column in type.resolve.constant("COLUMNS") %}
          @{{column[:name]}},
        {% end %}
      )
    end
  end

  macro setup_getters(type, *args, **named_args)
    {% for column in type.resolve.constant("COLUMNS") %}
      {% db_type = column[:type].is_a?(Generic) ? column[:type].type_vars.first : column[:type] %}
      def {{column[:name]}} : {% if column[:nilable] %}::Union({{db_type}}, ::Nil){% else %}{{column[:type]}}{% end %}
        %from_db = {{ db_type }}::Lucky.from_db!(@{{column[:name]}})
        {% if column[:nilable] %}
          %from_db.as?({{db_type}})
        {% else %}
          %from_db.as({{column[:type]}})
        {% end %}
      end
      {% if column[:type].id == Bool.id %}
      def {{column[:name]}}? : Bool
        !!{{column[:name]}}
      end
      {% end %}
    {% end %}
  end

  macro column(type_declaration, autogenerated = false)
    {% data_type = type_declaration.type %}
    {% nilable = false %}
    {% value = nil %}
    {% if data_type.is_a?(Union) %}
      {% data_type = data_type.types.first %}
      {% nilable = true %}
    {% end %}
    {% if type_declaration.value || type_declaration.value == false %}
      {% value = type_declaration.value %}
    {% end %}

    {% column_type = nil %}
    {% if data_type.id == Float64.id %}
      {% column_type = PG::Numeric %}
    {% elsif data_type.id == Array(Float64).id %}
      {% column_type = Array(PG::Numeric) %}
    {% elsif data_type.is_a?(Generic) %}
      {% column_type = data_type %}
    {% end %}
    property {{ type_declaration.var }} : {% if column_type.is_a?(NilLiteral) %}{{data_type.id}}::Lucky::ColumnType{% else %}{{column_type}}{% end %}{{(nilable ? "?" : "").id}}
    {% COLUMNS << {name: type_declaration.var, type: data_type, nilable: nilable, autogenerated: autogenerated, value: value} %}
  end

  macro setup_column_names_method(type, *args, **named_args)
    def self.column_names : Array(Symbol)
      [
        {% for column in type.resolve.constant("COLUMNS") %}
          {{column[:name].id.symbolize}},
        {% end %}
      ]
    end
  end

  macro association(table_name, type, relationship_type, foreign_key = nil, through = nil)
    {% ASSOCIATIONS << {type: type, table_name: table_name.id, foreign_key: foreign_key, relationship_type: relationship_type, through: through} %}
  end
end
