# frozen_string_literal: true

module RedmineIssueTemplate
  # An error or a warning about a file, shown on the file's page, in
  # Redmine's words: the key it is about and a validation sentence, as
  # Redmine shows "Subject cannot be blank".
  Message = Struct.new(:path, :level, :key, :params, keyword_init: true) do
    def self.error(path, key, **params)
      new(path: path, level: 'error', key: key.to_s, params: params.transform_keys(&:to_s))
    end

    def self.warning(path, key, **params)
      new(path: path, level: 'warning', key: key.to_s, params: params.transform_keys(&:to_s))
    end

    def error?
      level == 'error'
    end

    # The text in the user's language, with the file:
    # "bug.yml: body[2]: id is invalid", "config.yml is invalid".
    def text
      kind, subject = Message::SENTENCES.fetch(key, [:invalid])
      subject = interpolate(subject)
      scope = params['scope'] || (params.key?('index') ? "body[#{params['index']}]" : nil)
      return full_message(path, kind) if subject.nil? && scope.nil?
      return "#{path}: #{full_message(scope, kind)}" if subject.nil?

      [path, scope, full_message(subject, kind)].compact.join(': ')
    end

    private

    def full_message(subject, kind)
      message = if Message::CORE.include?(kind)
                  ::I18n.t("activerecord.errors.messages.#{kind}", count: params['count'])
                else
                  ::I18n.t("issue_template_error_#{kind}")
                end
      ::I18n.t('errors.format', attribute: subject, message: message,
                                default: '%{attribute} %{message}') # rubocop:disable Style/FormatStringToken
    end

    # The subject with the params filled in; nil when one is missing.
    def interpolate(subject)
      return nil if subject.nil?

      names = subject.scan(/%\{(\w+)\}/).flatten
      return nil unless names.all? { |name| params.key?(name) }

      subject.gsub(/%\{(\w+)\}/) { params[::Regexp.last_match(1)].to_s }
    end
  end

  # Sentences of the messages, by key (Message#text).
  class Message
    # How each message is written: [sentence, subject]. The sentence is core's
    # activerecord.errors.messages.<sentence> for CORE, otherwise
    # issue_template_error_<sentence>; %{...} in the subject comes from the
    # message's params. These are I18n's %{...} tokens, not format strings.
    # rubocop:disable Style/FormatStringToken
    CORE = %i[invalid blank taken inclusion exclusion too_short too_long].freeze
    SENTENCES = {
      'invalid_yaml' => [:not_yaml],
      'file_too_long' => [:too_long],
      'form_not_map' => [:invalid],
      'config_not_map' => [:invalid],
      'element_not_map' => [:invalid],
      'contact_link_not_map' => [:invalid],
      'front_matter_not_map' => [:invalid, 'front matter'],
      'body_not_array' => [:invalid, 'body'],
      'redmine_invalid_value' => [:invalid, '%{key}'],
      'invalid_value' => [:invalid, '%{key}'],
      'invalid_validation' => [:invalid, 'validations.%{key}'],
      'not_string' => [:invalid, '%{key}'],
      'label_not_string' => [:invalid, 'label'],
      'invalid_default' => [:invalid, 'default'],
      'invalid_id' => [:invalid, 'id'],
      'not_with_link' => [:not_with_link, '%{key}'],
      'invalid_contact_url' => [:invalid, 'url'],
      'no_front_matter' => [:blank, 'front matter'],
      'missing_key' => [:blank, '%{key}'],
      'missing_type' => [:blank, 'type'],
      'missing_attributes' => [:blank, 'attributes'],
      'missing_attribute' => [:blank, 'attributes.%{key}'],
      'checkbox_label' => [:blank, 'label'],
      'invalid_contact_link' => [:blank, '%{key}'],
      'body_empty' => [:blank, 'body'],
      'name_too_short' => [:too_short, 'name'],
      'duplicate_name' => [:taken, 'name: %{name}'],
      'duplicate_key' => [:taken, 'issue_template=%{key}'],
      'options_not_unique' => [:taken, 'options: %{value}'],
      'checkboxes_not_unique' => [:taken, 'options: %{value}'],
      'ids_not_unique' => [:taken, 'id: %{value}'],
      'labels_not_unique' => [:taken, 'label: %{value}'],
      'links_not_unique' => [:taken, 'link: %{value}'],
      'invalid_type' => [:inclusion, 'type'],
      'redmine_invalid_visibility' => [:inclusion, 'fields.%{field}'],
      'options_none' => [:exclusion, 'options: %{value}'],
      'forbidden_key' => [:quoted, '%{key}'],
      'options_boolean' => [:quoted, 'options: %{value}'],
      'not_permitted_key' => [:unknown_key, '%{key}'],
      'element_key' => [:unknown_key, '%{key}'],
      'attribute_key' => [:unknown_key, 'attributes.%{key}'],
      'validation_key' => [:unknown_key, 'validations.%{key}'],
      'config_unknown_key' => [:unknown_key, '%{key}'],
      'unknown_type' => [:not_found, 'type: %{type}'],
      'unknown_field' => [:not_found, 'fields: %{field}'],
      'unknown_custom_field' => [:not_found, 'custom_fields: %{field}'],
      'unknown_value' => [:not_found, '%{key}: %{value}'],
      'unknown_link' => [:not_found, 'link: %{link}'],
      'body_no_field' => [:no_field, 'body'],
      'labels_too_similar' => [:too_similar, 'label'],
      'labels_ignored' => [:ignored, 'labels: %{labels}'],
      'projects_ignored' => [:ignored, 'projects: %{projects}'],
      'assignees_ignored' => [:ignored, 'assignees: %{assignees}']
    }.freeze
    # rubocop:enable Style/FormatStringToken
  end
end
