# frozen_string_literal: true

module RedmineIssueTemplate
  # Redmine's keys of a template (docs/format.md#redmine-keys), at the top
  # level next to the other keys: the issue's attributes and the visibility
  # of the form's fields. Names are
  # resolved against a project when the template is used (#resolve).
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

    attr_reader :tracker, :priority, :category, :fixed_version, :is_private, :custom_fields, :fields

    # data: the template's top-level keys.
    def self.parse(path, data, errors)
      options = new(data.slice(*ATTRIBUTES))
      options.check(path, errors)
      options
    end

    def initialize(data)
      @tracker = data['tracker']&.to_s
      @priority = data['priority']&.to_s
      @category = data['category']&.to_s
      @fixed_version = data['fixed_version']&.to_s
      @is_private = data['is_private']
      @custom_fields = data['custom_fields'].is_a?(Hash) ? data['custom_fields'].transform_keys(&:to_s) : {}
      @fields = data['fields'].is_a?(Hash) ? data['fields'].transform_keys(&:to_s).transform_values(&:to_s) : {}
      @raw = data
    end

    def check(path, errors)
      if @raw.key?('is_private') && ![true, false].include?(is_private)
        errors << Message.error(path, :redmine_invalid_value, key: 'is_private')
      end
      if @raw.key?('custom_fields') && !@raw['custom_fields'].is_a?(Hash)
        errors << Message.error(path, :redmine_invalid_value,
                                key: 'custom_fields')
      end
      if @raw.key?('fields') && !@raw['fields'].is_a?(Hash)
        errors << Message.error(path, :redmine_invalid_value,
                                key: 'fields')
      end
      fields.each do |name, value|
        unless VISIBILITY.include?(value)
          errors << Message.error(path, :redmine_invalid_visibility, field: name,
                                                                     value: value)
        end
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

    private

    def custom_field(project, name)
      fields = project.all_issue_custom_fields
      fields.detect { |field| field.id.to_s == name.to_s } || fields.detect { |field| field.name.casecmp?(name.to_s) }
    end

    def find_named(scope, name)
      return nil if name.blank?

      scope.detect { |record| record.id.to_s == name } || scope.detect { |record| record.name.casecmp?(name) }
    end
  end
end
