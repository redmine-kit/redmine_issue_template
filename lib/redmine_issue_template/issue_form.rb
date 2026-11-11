# frozen_string_literal: true

module RedmineIssueTemplate
  # A YAML issue form (docs/format.md), checked with the plugin's
  # rules for its keys and fields.
  class IssueForm < Template
    include IssueFormOptions

    TOP_LEVEL_KEYS = (%w[name description title labels assignees projects type body] + RedmineOptions::ATTRIBUTES).freeze
    ELEMENT_KEYS = %w[type id attributes validations link].freeze
    TYPES = %w[markdown textarea input dropdown checkboxes upload].freeze
    # A field with a `link` has no type: the field it sets decides
    # (LinkedField), and the element is of this kind.
    LINK = 'link'
    ATTRIBUTES = {
      LINK => %w[label description placeholder options],
      'markdown' => %w[value],
      'textarea' => %w[label description placeholder value render],
      'input' => %w[label description placeholder value],
      'dropdown' => %w[label description multiple options default],
      'checkboxes' => %w[label description options],
      'upload' => %w[label description]
    }.freeze
    VALIDATIONS = {
      LINK => %w[required],
      'markdown' => [],
      'textarea' => %w[required min_length],
      'input' => %w[required min_length],
      'dropdown' => %w[required],
      'checkboxes' => %w[required],
      'upload' => %w[required accept]
    }.freeze
    ID = /\A[A-Za-z0-9_-]+\z/

    # One element of the form's body.
    Element = Struct.new(:index, :type, :id, :attributes, :validations, :link, keyword_init: true) do
      def field?
        type != 'markdown'
      end

      def label
        attributes['label'].to_s
      end

      # The name of the answer in the form's parameters: the id, or else the
      # label made into a parameter, or else (a label without Latin letters
      # or digits) the field's place in the body.
      def ref
        id.presence || label.parameterize.presence || "field-#{index}"
      end

      def linked?
        type == LINK
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

    # Links that the project doesn't have, as warnings.
    def project_warnings(project)
      unknown = fields.select { |element| element.link && LinkedField.resolve(project, element.link).nil? }
      super + unknown.map { |element| Message.warning(path, :unknown_link, field: element.label, link: element.link) }
    end

    def read(content)
      @content = content
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
      return unless data['name'].is_a?(String) && data['name'].strip.length <= 3

      errors << Message.error(path, :name_too_short, count: 4)
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
                               validations: validations, link: type == LINK ? item['link'].strip : nil)
    end

    # The element's type, or nil after reporting why it has none.
    def element_type(item, index)
      return element_error(index, :element_not_map) unless item.is_a?(Hash)
      return link_type(item, index) if item.key?('link')

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

    # A field with a link (docs/format.md#links): without a type.
    def link_type(item, index)
      return element_error(index, :not_with_link, key: 'type') if item.key?('type')

      link = item['link']
      return element_error(index, :not_string, key: 'link') unless link.is_a?(String) && link.strip.present?

      LINK
    end

    def check_attributes(index, type, attributes)
      (attributes.keys.map(&:to_s) - ATTRIBUTES[type]).each { |key| element_error(index, :attribute_key, key: key) }
      if type == 'markdown'
        element_error(index, :missing_attribute, key: 'value') unless attributes['value'].is_a?(String)
        return
      end
      element_error(index, :missing_attribute, key: 'label') unless attributes.key?('label')
      element_error(index, :label_not_string) if attributes.key?('label') && !attributes['label'].is_a?(String)
      check_options(index, type, attributes)
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

    def element_error(index, key, **params)
      errors << Message.error(path, key, index: index, **params)
      nil
    end
  end
end
