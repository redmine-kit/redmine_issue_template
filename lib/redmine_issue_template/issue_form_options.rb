# frozen_string_literal: true

module RedmineIssueTemplate
  # The checks of the options of an issue form's fields: part of IssueForm.
  module IssueFormOptions
    private

    def check_options(index, type, attributes)
      case type
      when 'dropdown' then check_dropdown(index, attributes)
      when 'checkboxes' then check_checkboxes(index, attributes)
      when IssueForm::LINK then check_link_options(index, attributes['options']) if attributes.key?('options')
      end
    end

    def check_dropdown(index, attributes)
      options = attributes['options']
      return element_error(index, :missing_attribute, key: 'options') unless options.is_a?(Array) && options.any?

      problem, value = dropdown_options_problem(index, options)
      return element_error(index, problem, value: value) if problem

      default = attributes['default']
      return if default.nil? || (default.is_a?(Integer) && default.between?(0, options.size - 1))

      element_error(index, :invalid_default)
    end

    # A link's options narrow the field's choices.
    def check_link_options(index, options)
      return element_error(index, :invalid_value, key: 'options') unless options.is_a?(Array) && options.any?

      problem, value = dropdown_options_problem(index, options)
      element_error(index, problem, value: value) if problem
    end

    # [problem, the option it is about], or nil.
    def dropdown_options_problem(index, options)
      if options.intersect?([true, false])
        [:options_boolean, boolean_option(index) || options.find { |option| [true, false].include?(option) }]
      elsif (duplicate = Parser.duplicate(options.map(&:to_s)))
        [:options_not_unique, duplicate]
      elsif (none = options.find { |option| option.to_s.strip.casecmp?('none') })
        [:options_none, none]
      end
    end

    # A boolean option as it is written in the file (yes, on, true...).
    def boolean_option(index)
      node = YamlNodes.yaml_node(@content, 'body', index, 'attributes', 'options')
      node&.children&.find { |child| YamlNodes.boolean_word?(child) }&.value
    end

    def check_checkboxes(index, attributes)
      options = attributes['options']
      return element_error(index, :missing_attribute, key: 'options') unless options.is_a?(Array) && options.any?
      unless options.all? { |option| option.is_a?(Hash) && option['label'].is_a?(String) }
        return element_error(index, :checkbox_label)
      end

      duplicate = Parser.duplicate(options.map { |option| option['label'] })
      element_error(index, :checkboxes_not_unique, value: duplicate) if duplicate
    end
  end
end
