module Avram::Callbacks
  macro register_event(event_name, *types)
    getter _{{event_name.id}}_callbacks = Hash(String, Proc(
      {% for type in types %}
        {{ type.id }},
      {% end %}
      Nil)).new

    def _run_{{ event_name.id }}(
      {% for type, index in types %}
        %param{index} : {{ type.id }},
      {% end %}
    )
      puts "asdfjasd"
      _{{ event_name.id }}
      puts "asdfjasd"
      pp _{{ event_name.id }}_callbacks.keys
      _{{ event_name.id }}_callbacks.values.each(&.call(
        {% for _type, index in types %}
          %param{index},
        {% end %}
      ))
    end

    def _{{ event_name.id }}
    end

    macro {{ event_name.id }}(method_name, **args)
      def _{{ event_name.id }}
        \{% if @type.methods.map(&.name).includes?(:_{{ event_name.id }}.id) %}
          previous_def
        \{% else %}
          super
        \{% end %}

        \{% if args[:if] != nil %}
          return unless \{{ args[:if] }}.call
        \{% end %}
        _{{event_name.id}}_callbacks[\{{ method_name.stringify }}] = ->\{{ method_name.id }}{% unless types.empty? %}(
          {% for _type in types %}
            type,
          {% end %}
        ){% end %}
      end
    end

    macro {{ event_name.id }}(&block)
      def _{{ event_name.id }}
        \{% if @type.methods.map(&.name).includes?(:_{{ event_name.id }}.id) %}
          previous_def
        \{% else %}
          super
        \{% end %}
        temp = _{{ event_name.id }}_callbacks["COMPLETELY_UNUSED-arg123"] ||= ->(
          {% for type, index in types %}
            %param{index} : {{ type.id }},
          {% end %}
        ){}
        _{{ event_name.id }}_callbacks["COMPLETELY_UNUSED-arg123"] = ->(
          {% for type, index in types %}
            %param{index} : {{ type.id }},
          {% end %}
        ) do
          temp.call(
            {% for _type, index in types %}
              %param{index}
            {% end %}
          )
          {% for type, index in types %}
            \{% if block.args[{{ index }}] != nil %}
              \{{ block.args[{{ index }}] }} = %param{index}
            \{% end %}
          {% end %}
          \{{ block.body }}
        end
      end
    end

    macro skip_{{ event_name.id }}(method_name, **args)
      def _{{ event_name.id }}
        \{% if @type.methods.map(&.name).includes?(:_{{ event_name.id }}.id) %}
          previous_def
        \{% else %}
          super
        \{% end %}
        \{% if args[:if] != nil %}
          return unless \{{ args[:if] }}.call
        \{% end %}
        _{{event_name.id}}_callbacks.delete(\{{ method_name.stringify }})
      end
    end
  end

  # we do this because we have to make the core method a different name than is registered
  # b/c crystal checks for available macros before checking for methods so they can't be
  # the same name
  macro run_event(event_name, *args)
    _run_{{ event_name.id }}({{ *args }})
  end
end
