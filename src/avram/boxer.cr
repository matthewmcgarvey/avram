abstract class Avram::Boxer
  getter operation
  class_getter attribute_setters, association_setters
  
  macro inherited
    {% model_name = @type.name.gsub(/Boxer/, "").id %}
    {% operation = model_name + "::SaveOperation" %}
    @operation : {{ operation }} = {{ operation }}.new
    @@attribute_setters = {} of String => Proc({{operation}}, Nil)
    @@association_setters = {} of String => Proc({{model_name}}, Nil)
    setup_attribute_shortcuts({{ operation }})
    setup_association_shortcuts({{ model_name }})
  end

  macro setup_attribute_shortcuts(operation)
    {% for attribute in operation.resolve.constant(:COLUMN_ATTRIBUTES) %}
      def {{ attribute[:name] }}(value : {{ attribute[:type] }}{% if attribute[:nilable] %}?{% end %})
        self.{{ attribute[:name] }}(value)
      end

      def self.{{ attribute[:name] }}(value : {{ attribute[:type] }}{% if attribute[:nilable] %}?{% end %})
        attribute_setters["{{ attribute[:name] }}"] = ->(operation : {{ operation }}) do 
          operation.{{ attribute[:name] }}.value = value
        end
      end
    {% end %}
  end

  macro setup_association_shortcuts(model_class)
    {% for association in model_class.resolve.constant(:ASSOCIATIONS) %}
      {% assoc_name = association[:foreign_key].id.gsub(/_id/, "") %}
      def self.{{ assoc_name }}(value : {{ association[:type] }}Boxer.class)
        assoc_model = value.create
        {{ association[:foreign_key].id }}(assoc_model.id)
        association_setters["{{ assoc_name }}"] = ->(model : {{ model_class }}) do
          model.__set_preloaded_{{ assoc_name }}(assoc_model)
        end
      end
    {% end %}
  end

  def self.create
    new.create
  end

  def create
    self.class.attribute_setters.each do |k,v|
      v.call(operation)
    end
    result = operation.save!
    self.class.association_setters.each do |k,v|
      v.call(result)
    end
    result
  end
end
