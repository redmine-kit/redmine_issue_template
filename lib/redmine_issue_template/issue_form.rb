# frozen_string_literal: true

module RedmineIssueTemplate
  # A YAML issue form (GitHub's "Syntax for issue forms" and "Syntax for
  # GitHub's form schema"), checked with GitHub's rules
  # ("Common validation errors when creating issue forms").
  class IssueForm < Template
    TOP_LEVEL_KEYS = %w[name description title labels assignees projects type body redmine].freeze
    ELEMENT_KEYS = %w[type id attributes validations].freeze
    TYPES = %w[markdown textarea input dropdown checkboxes upload].freeze
    ATTRIBUTES = {
      'markdown' => %w[value],
      'textarea' => %w[label description placeholder value render],
      'input' => %w[label description placeholder value],
      'dropdown' => %w[label description multiple options default],
      'checkboxes' => %w[label description options],
      'upload' => %w[label description]
    }.freeze
    VALIDATIONS = {
      'markdown' => [],
      'textarea' => %w[required min_length],
      'input' => %w[required min_length],
      'dropdown' => %w[required],
      'checkboxes' => %w[required],
      'upload' => %w[required accept]
    }.freeze
    ID = /\A[A-Za-z0-9_-]+\z/

    # One element of the form's body.
    Element = Struct.new(:index, :type, :id, :attributes, :validations, keyword_init: true) do
      def field?
        type != 'markdown'
      end

      def label
        attributes['label'].to_s
      end

      # The name of the answer in the form's parameters: the id, or the
      # label made into a parameter as GitHub does.
      def ref
        id.presence || label.parameterize
      end

      def required?
        validations['required'] == true
      end

      def min_length
        validations['min_length']
      end

      def options
        attributes['options'] || []
      end

      def multiple?
        attributes['multiple'] == true
      end

      # Checkbox options as { label:, required: }.
      def checkbox_options
        options.map { |option| { label: option['label'].to_s, required: option['required'] == true } }
      end
    end

    attr_reader :elements

    def self.parse(path, content)
      form = new(path)
      form.read(content.to_s)
      form
    end

    def form?
      true
    end

    def fields
      elements.select(&:field?)
    end

    def read(content)
      @elements = []
      data = Parser.load_yaml(path, content, errors)
      return if data.nil?
      return errors << Message.error(path, :form_not_map) unless data.is_a?(Hash)

      check_top_level(data)
      read_common(data, 'description')
      read_body(data['body'])
    end

    private

    def check_top_level(data)
      (data.keys.map(&:to_s) - TOP_LEVEL_KEYS).each do |key|
        errors << Message.error(path, :not_permitted_key, key: key)
      end
      %w[name description body].each do |key|
        errors << Message.error(path, :missing_key, key: key) unless data.key?(key)
      end
      %w[name description title type].each do |key|
        errors << Message.error(path, :not_string, key: key) unless data[key].nil? || data[key].is_a?(String)
      end
      errors << Message.error(path, :name_too_short) if data['name'].is_a?(String) && data['name'].strip.length <= 3
    end

    def read_body(body)
      return if body.nil?
      return errors << Message.error(path, :body_not_array) unless body.is_a?(Array)
      return errors << Message.error(path, :body_empty) if body.empty?

      body.each_with_index { |item, index| read_element(item, index) }
      errors << Message.error(path, :body_no_field) if valid? && fields.empty?
      check_unique_ids
      check_unique_labels
    end

    def read_element(item, index)
      type = element_type(item, index)
      return if type.nil?

      check_element_keys(item, index, type)
      attributes = item['attributes']
      return element_error(index, :missing_attributes) unless attributes.is_a?(Hash)

      validations = item['validations'].is_a?(Hash) ? item['validations'] : {}
      check_attributes(index, type, attributes)
      check_validations(index, type, validations)
      @elements << Element.new(index: index, type: type, id: item['id']&.to_s, attributes: attributes,
                               validations: validations)
    end

    # The element's type, or nil after reporting why it has none.
    def element_type(item, index)
      return element_error(index, :element_not_map) unless item.is_a?(Hash)

      type = item['type']
      return element_error(index, :missing_type) if type.nil?
      return element_error(index, :invalid_type, type: type) unless TYPES.include?(type)

      type
    end

    def check_element_keys(item, index, type)
      keys = item.keys.map(&:to_s)
      not_permitted = keys - ELEMENT_KEYS
      not_permitted |= keys & %w[id validations] if type == 'markdown'
      not_permitted.each { |key| element_error(index, :element_key, key: key) }
      element_error(index, :invalid_id) if item['id'] && !ID.match?(item['id'].to_s)
    end

    def check_attributes(index, type, attributes)
      (attributes.keys.map(&:to_s) - ATTRIBUTES[type]).each { |key| element_error(index, :attribute_key, key: key) }
      if type == 'markdown'
        element_error(index, :missing_attribute, key: 'value') unless attributes['value'].is_a?(String)
        return
      end
      element_error(index, :missing_attribute, key: 'label') unless attributes.key?('label')
      element_error(index, :label_not_string) if attributes.key?('label') && !attributes['label'].is_a?(String)
      check_dropdown(index, attributes) if type == 'dropdown'
      check_checkboxes(index, attributes) if type == 'checkboxes'
    end

    def check_dropdown(index, attributes)
      options = attributes['options']
      return element_error(index, :missing_attribute, key: 'options') unless options.is_a?(Array) && options.any?

      problem = dropdown_options_problem(options)
      return element_error(index, problem) if problem

      default = attributes['default']
      return if default.nil? || (default.is_a?(Integer) && default.between?(0, options.size - 1))

      element_error(index, :invalid_default)
    end

    def dropdown_options_problem(options)
      if options.intersect?([true, false]) then :options_boolean
      elsif options.map(&:to_s).uniq.size < options.size then :options_not_unique
      elsif options.any? { |option| option.to_s.strip.casecmp?('none') } then :options_none
      end
    end

    def check_checkboxes(index, attributes)
      options = attributes['options']
      return element_error(index, :missing_attribute, key: 'options') unless options.is_a?(Array) && options.any?
      unless options.all? { |option| option.is_a?(Hash) && option['label'].is_a?(String) }
        return element_error(index, :checkbox_label)
      end

      labels = options.map { |option| option['label'] }
      element_error(index, :checkboxes_not_unique) if labels.uniq.size < labels.size
    end

    def check_validations(index, type, validations)
      (validations.keys.map(&:to_s) - VALIDATIONS[type]).each { |key| element_error(index, :validation_key, key: key) }
      if validations.key?('required') && ![true, false].include?(validations['required'])
        element_error(index, :invalid_validation, key: 'required')
      end
      return unless validations.key?('min_length')
      return if validations['min_length'].is_a?(Integer) && validations['min_length'] >= 0

      element_error(index, :invalid_validation, key: 'min_length')
    end

    def check_unique_ids
      ids = elements.filter_map(&:id)
      errors << Message.error(path, :ids_not_unique) if ids.uniq.size < ids.size
    end

    # Labels of the fields must be unique, and fields without an id must not
    # have labels that become the same parameter.
    def check_unique_labels
      labels = fields.map(&:label)
      errors << Message.error(path, :labels_not_unique) if labels.uniq.size < labels.size
      refs = fields.reject(&:id).map { |element| element.label.parameterize }
      return unless refs.uniq.size < refs.size && labels.uniq.size == labels.size

      errors << Message.error(path,
                              :labels_too_similar)
    end

    def element_error(index, key, **params)
      errors << Message.error(path, key, index: index, **params)
      nil
    end
  end
end
