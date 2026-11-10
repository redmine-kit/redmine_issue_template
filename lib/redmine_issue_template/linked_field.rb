# frozen_string_literal: true

module RedmineIssueTemplate
  # A field of an issue form linked to a field of the issue (the element's
  # `link`, docs/format.md#links): the answer sets that field, which the
  # form then leaves out, and is not written into the description.
  class LinkedField
    # The issue's fields a form's field can set, and their attributes.
    ATTRIBUTES = {
      'priority' => 'priority_id', 'category' => 'category_id', 'fixed_version' => 'fixed_version_id',
      'assigned_to' => 'assigned_to_id', 'start_date' => 'start_date', 'due_date' => 'due_date',
      'estimated_hours' => 'estimated_hours', 'done_ratio' => 'done_ratio'
    }.freeze
    TYPES = %w[input textarea dropdown].freeze

    attr_reader :element, :attribute

    # The form's linked fields that the project has: [LinkedField, ...].
    def self.for(form, project)
      return [] unless form.form? && project

      form.fields.filter_map do |element|
        attribute = resolve(project, element.link)
        new(element, attribute) if attribute
      end
    end

    # 'fixed_version_id', a custom field's id ("3"), or nil.
    def self.resolve(project, name)
      return nil if name.blank?

      ATTRIBUTES[name.to_s] || RedmineOptions.find_custom_field(project, name)&.id&.to_s
    end

    def initialize(element, attribute)
      @element = element
      @attribute = attribute
    end

    def custom_field?
      attribute.match?(/\A\d+\z/)
    end

    # The dropdown's choices for the issue: [[label, value], ...]. The
    # template's options, matched by name with the issue's choices, or else
    # the issue's choices.
    def choices(issue)
      available = issue_choices(issue)
      return available if element.options.empty?

      # A field without a list of values (text) takes the option as it is.
      return element.options.map { |option| [option.to_s, option.to_s] } if available.empty?

      element.options.map do |option|
        label = option.to_s
        [label, available.find { |name, _| name.to_s.casecmp?(label) }&.last]
      end
    end

    # Sets the issue's field from the posted answer, unless the tracker
    # disables the field.
    def apply(issue, answer)
      return if !custom_field? && issue.disabled_core_fields.include?(attribute)

      value = element.type == 'dropdown' ? chosen(issue, answer) : answer.to_s.strip
      if custom_field?
        issue.custom_field_values = { attribute => value }
      else
        issue.public_send("#{attribute}=", value.presence)
      end
    end

    private

    def chosen(issue, answer)
      list = choices(issue)
      values = Array(answer).filter_map do |index|
        list[index.to_i]&.last if index.to_s.match?(/\A\d+\z/)
      end
      element.multiple? ? values.map(&:to_s) : values.first.to_s
    end

    def issue_choices(issue)
      case attribute
      when 'priority_id' then IssuePriority.active.map { |priority| [priority.name, priority.id] }
      when 'category_id' then issue.project.issue_categories.map { |category| [category.name, category.id] }
      when 'fixed_version_id' then version_choices(issue)
      when 'assigned_to_id' then issue.assignable_users.map { |principal| [principal.name, principal.id] }
      when 'done_ratio' then (0..10).map { |step| ["#{step * 10} %", step * 10] }
      else custom_field_choices(issue)
      end
    end

    # As Redmine names versions: shared versions of other projects with the
    # project's name.
    def version_choices(issue)
      issue.assignable_versions.map do |version|
        [version.project == issue.project ? version.name : version.to_s_with_project, version.id]
      end
    end

    def custom_field_choices(issue)
      return [] unless custom_field?

      field = issue.available_custom_fields.detect { |custom_field| custom_field.id.to_s == attribute }
      return [] unless field

      # Empty for fields without a list of values (text, numbers, dates).
      field.possible_values_options(issue).map { |option| option.is_a?(Array) ? option : [option, option] }
    end
  end
end
