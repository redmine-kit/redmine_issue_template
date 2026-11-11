# frozen_string_literal: true

module RedmineIssueTemplate
  # The checks of an issue form's keys, fields and options: part of
  # IssueForm.
  module IssueFormChecks
    # An extension in accept, such as ".png" or ".tar.gz".
    ACCEPT = /\A(\.[A-Za-z0-9]+)+\z/

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

    def check_top_level(data)
      keys = data.keys.map(&:to_s)
      (keys - IssueForm::TOP_LEVEL_KEYS).each { |key| errors << Message.error(path, :not_permitted_key, key: key) }
      (%w[name description body] - keys).each { |key| errors << Message.error(path, :missing_key, key: key) }
      check_strings(data)
    end

    def check_strings(data)
      %w[name description title type].reject { |key| data[key].nil? || data[key].is_a?(String) }.each do |key|
        errors << Message.error(path, :not_string, key: key)
      end
      name = data['name']
      errors << Message.error(path, :name_too_short, count: 4) if name.is_a?(String) && name.strip.length <= 3
    end

    def check_validations(index, type, validations)
      (validations.keys.map(&:to_s) - IssueForm::VALIDATIONS[type]).each { |key| element_error(index, :validation_key, key: key) }
      if validations.key?('required') && ![true, false].include?(validations['required'])
        element_error(index, :invalid_validation, key: 'required')
      end
      check_accept(index, validations) if type == 'upload'
      return unless validations.key?('min_length')
      return if validations['min_length'].is_a?(Integer) && validations['min_length'] >= 0

      element_error(index, :invalid_validation, key: 'min_length')
    end

    # accept: extensions separated by commas, such as ".png,.jpg,.tar.gz".
    def check_accept(index, validations)
      return unless validations.key?('accept')

      value = validations['accept']
      extensions = value.is_a?(String) ? value.split(',').map(&:strip) : []
      return if extensions.any? && extensions.all? { |extension| ACCEPT.match?(extension) }

      element_error(index, :invalid_validation, key: 'accept')
    end

    def check_unique_ids
      duplicate = Parser.duplicate(elements.filter_map(&:id))
      errors << Message.error(path, :ids_not_unique, value: duplicate) if duplicate
      duplicate = Parser.duplicate(elements.filter_map(&:link))
      errors << Message.error(path, :links_not_unique, value: duplicate) if duplicate
    end

    # Labels of the fields must be unique, and no two fields may post their
    # answers under the same name (an id, or a label made into one).
    def check_unique_labels
      duplicate = Parser.duplicate(fields.map(&:label))
      return errors << Message.error(path, :labels_not_unique, value: duplicate) if duplicate

      return if Parser.duplicate(elements.filter_map(&:id))

      errors << Message.error(path, :labels_too_similar) if Parser.duplicate(fields.map(&:ref))
    end
  end
end
