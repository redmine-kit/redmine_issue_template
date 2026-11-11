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

    # The links that apply to the new issue: the field exists in the project
    # and Redmine lets the user set it (Issue#issue_template_settable?). The
    # first of two links to the same field wins.
    def self.for(issue)
      form = issue.issue_template
      return [] unless form&.form? && issue.project

      linked = []
      form.fields.each do |element|
        attribute = resolve(issue.project, element.link)
        next if attribute.nil? || linked.any? { |link| link.attribute == attribute }
        next unless issue.issue_template_settable?(attribute)

        linked << new(element, attribute)
      end
      linked
    end

    # Linked fields that can't apply and have no options of their own: the
    # form leaves them out, since they would have nothing to choose.
    def self.dropped(form, links)
      return [] unless form.form?

      linked = links.map(&:element)
      form.fields.select { |element| element.link && element.options.empty? && !linked.include?(element) }
    end

    # The attributes the form's links name in the project, whether they apply
    # or not: the request can't set them.
    def self.attributes(form, project)
      return [] unless form.form?

      form.fields.filter_map { |element| resolve(project, element.link) }.uniq
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

    # Sets the issue's field from the posted answer. A blank answer leaves
    # Redmine's default.
    def apply(issue, answer)
      value = element.type == 'dropdown' ? chosen(issue, answer) : answer.to_s.strip
      return if value.blank?

      if custom_field?
        issue.custom_field_values = { attribute => value }
      else
        issue.public_send("#{attribute}=", value)
      end
    end

    private

    # The chosen values; one, unless the field takes several.
    def chosen(issue, answer)
      list = choices(issue)
      values = Array(answer).filter_map do |index|
        list[index.to_i]&.last&.to_s if index.to_s.match?(/\A\d+\z/)
      end
      custom_field(issue)&.multiple? ? values : values.first
    end

    def custom_field(issue)
      return nil unless custom_field?

      issue.available_custom_fields.detect { |field| field.id.to_s == attribute }
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

    # Empty for fields without a list of values (text, numbers, dates).
    def custom_field_choices(issue)
      custom_field(issue)&.possible_values_options(issue).to_a.map { |option| Array(option).values_at(0, -1) }
    end

    # As Redmine names versions: shared versions of other projects with the
    # project's name.
    def version_choices(issue)
      issue.assignable_versions.map do |version|
        [version.project == issue.project ? version.name : version.to_s_with_project, version.id]
      end
    end
  end
end
