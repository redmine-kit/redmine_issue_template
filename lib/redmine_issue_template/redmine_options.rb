# frozen_string_literal: true

module RedmineIssueTemplate
  # Redmine's keys of a template (docs/format.md#redmine-keys): the issue's
  # attributes and the visibility of the form's fields. Names are resolved
  # against a project when the template is used.
  class RedmineOptions
    ATTRIBUTES = %w[tracker priority category fixed_version is_private custom_fields fields].freeze
    # Fields of the issue form whose visibility a template can set, and the
    # issue attribute each one stands for.
    FIELDS = {
      'assigned_to' => 'assigned_to_id', 'category' => 'category_id', 'fixed_version' => 'fixed_version_id',
      'parent_issue' => 'parent_issue_id', 'start_date' => 'start_date', 'due_date' => 'due_date',
      'estimated_hours' => 'estimated_hours', 'done_ratio' => 'done_ratio', 'description' => 'description',
      'priority' => 'priority_id', 'is_private' => 'is_private', 'watchers' => 'watcher_user_ids'
    }.freeze
    VISIBILITY = %w[shown hidden required].freeze
    NEVER_REQUIRED = %w[is_private priority].freeze

    attr_reader :tracker, :priority, :category, :fixed_version, :is_private, :custom_fields, :fields

    # data: the template's top-level keys.
    def self.parse(path, data, errors)
      options = new(data.slice(*ATTRIBUTES))
      options.check(path, errors)
      options
    end

    def initialize(data)
      @tracker, @priority, @category, @fixed_version =
        data.values_at('tracker', 'priority', 'category', 'fixed_version').map { |value| value&.to_s }
      @is_private = data['is_private']
      @custom_fields = string_keys(data['custom_fields'])
      @fields = string_keys(data['fields']).transform_values(&:to_s)
      @raw = data
    end

    # The keys whose values must be of a kind: [key, what it must be].
    KINDS = [['is_private', ->(value) { [true, false].include?(value) }],
             ['custom_fields', ->(value) { value.is_a?(Hash) }],
             ['fields', ->(value) { value.is_a?(Hash) }]].freeze

    def check(path, errors)
      KINDS.each do |key, valid|
        errors << Message.error(path, :redmine_invalid_value, key: key) if @raw.key?(key) && !valid.call(@raw[key])
      end
      fields.each do |name, value|
        # Always set, as in Redmine's workflow, which can't require them either.
        next if VISIBILITY.include?(value) && !(value == 'required' && NEVER_REQUIRED.include?(name))

        errors << Message.error(path, :redmine_invalid_visibility, field: name, value: value)
      end
    end

    # The visibility of the form's fields, resolved against the project:
    # { hidden: ["assigned_to_id", "3"], required: ["due_date"] }, custom
    # fields by id. Unknown fields become warnings.
    def visibility(project, warnings = [], path = nil)
      result = { hidden: [], required: [] }
      fields.each do |name, value|
        next if value == 'shown'

        attribute = FIELDS[name] || custom_field(project, name)&.id&.to_s
        if attribute.nil?
          warnings << Message.warning(path, :unknown_field, field: name)
          next
        end
        result[value.to_sym] << attribute
      end
      result
    end

    def tracker_record(project)
      find_named(project.trackers, tracker)
    end

    def priority_record
      find_named(IssuePriority.active, priority)
    end

    def category_record(project)
      find_named(project.issue_categories, category)
    end

    def fixed_version_record(project)
      find_named(project.shared_versions.open, fixed_version)
    end

    # { custom_field_id => value } for the project's issue custom fields.
    def custom_field_values(project, warnings = [], path = nil)
      custom_fields.each_with_object({}) do |(name, value), values|
        field = custom_field(project, name)
        if field
          values[field.id.to_s] = value.is_a?(Array) ? value.map(&:to_s) : value.to_s
        else
          warnings << Message.warning(path, :unknown_custom_field, field: name)
        end
      end
    end

    # Checks the names against a project, for the warnings of an import.
    def resolve(project, path)
      warnings = []
      { 'tracker' => tracker.present? && tracker_record(project).nil?,
        'priority' => priority.present? && priority_record.nil?,
        'category' => category.present? && category_record(project).nil?,
        'fixed_version' => fixed_version.present? && fixed_version_record(project).nil? }.each do |key, missing|
        warnings << Message.warning(path, :unknown_value, key: key, value: public_send(key)) if missing
      end
      custom_field_values(project, warnings, path)
      visibility(project, warnings, path)
      warnings
    end

    # A custom field of the project's issues, by id or by name without case.
    def self.find_custom_field(project, name)
      fields = project.all_issue_custom_fields
      fields.detect { |field| field.id.to_s == name.to_s } || fields.detect { |field| field.name.casecmp?(name.to_s) }
    end

    private

    def string_keys(value)
      value.is_a?(Hash) ? value.transform_keys(&:to_s) : {}
    end

    def custom_field(project, name)
      self.class.find_custom_field(project, name)
    end

    def find_named(scope, name)
      return nil if name.blank?

      scope.detect { |record| record.id.to_s == name } || scope.detect { |record| record.name.casecmp?(name) }
    end
  end
end
