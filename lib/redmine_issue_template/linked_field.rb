# frozen_string_literal: true

module RedmineIssueTemplate
  # A field of an issue form linked to a field of the issue (the element's
  # `link`, docs/format.md#links): the field it sets decides how it is
  # shown, the answer sets that field, which the form then leaves out, and
  # the answer is not written into the description.
  class LinkedField
    # The issue's fields a form's field can set, and their attributes.
    ATTRIBUTES = {
      'priority' => 'priority_id', 'category' => 'category_id', 'fixed_version' => 'fixed_version_id',
      'assigned_to' => 'assigned_to_id', 'start_date' => 'start_date', 'due_date' => 'due_date',
      'estimated_hours' => 'estimated_hours', 'done_ratio' => 'done_ratio'
    }.freeze
    CHOICES = %w[priority_id category_id fixed_version_id assigned_to_id done_ratio].freeze
    DATES = %w[start_date due_date].freeze
    # Custom field formats shown as a select, and as a text area.
    SELECT_FORMATS = %w[list enumeration user version bool].freeze
    TEXT_FORMATS = %w[text].freeze

    attr_reader :element, :attribute

    # The links that apply to the new issue: the field exists in the project
    # and Redmine lets the user set it (Issue#issue_template_settable?). The
    # first of two links to the same field wins.
    def self.for(issue)
      form = issue.issue_template
      return [] unless form&.form? && issue.project

      linked = []
      form.fields.select(&:linked?).each do |element|
        attribute = resolve(issue.project, element.link)
        next if attribute.nil? || linked.any? { |link| link.attribute == attribute }
        next unless issue.issue_template_settable?(attribute)

        linked << new(element, attribute)
      end
      linked
    end

    # Linked fields that can't apply and have no options of their own: the
    # form leaves them out, since it couldn't show them.
    def self.dropped(form, links)
      return [] unless form.form?

      linked = links.map(&:element)
      form.fields.select { |element| element.linked? && element.options.empty? && !linked.include?(element) }
    end

    # The attributes the form's links name in the project, whether they apply
    # or not: the request can't set them.
    def self.attributes(form, project)
      return [] unless form.form?

      form.fields.filter_map { |element| resolve(project, element.link) }.uniq
    end

    # 'fixed_version_id', a custom field's id ("3"), or nil. File custom
    # fields can't be set from a form's field, nor % done when the issue's
    # status sets it.
    def self.resolve(project, name)
      return nil if name.blank?
      return nil if name.to_s == 'done_ratio' && !Issue.use_field_for_done_ratio?
      return ATTRIBUTES[name.to_s] if ATTRIBUTES.key?(name.to_s)

      field = RedmineOptions.find_custom_field(project, name)
      field.id.to_s if field && field.field_format != 'attachment'
    end

    def initialize(element, attribute)
      @element = element
      @attribute = attribute
    end

    def custom_field?
      attribute.match?(/\A\d+\z/)
    end

    # How the form shows the field: :select, :date, :textarea or :text.
    def kind(issue)
      return :select if CHOICES.include?(attribute)
      return :date if DATES.include?(attribute)
      return :text unless custom_field?

      format = custom_field(issue)&.field_format
      return :select if SELECT_FORMATS.include?(format)
      return :date if format == 'date'

      TEXT_FORMATS.include?(format) ? :textarea : :text
    end

    def multiple?(issue)
      kind(issue) == :select && custom_field(issue)&.multiple? == true
    end

    # The select's choices for the issue: [[label, value], ...], values as
    # strings. The template's options keep the choices of the same names or
    # values; when none matches (labels in another language), all choices.
    def choices(issue)
      available = issue_choices(issue).map { |label, value| [label.to_s, value.to_s] }
      kept = element.options.filter_map do |option|
        available.find { |label, value| label.casecmp?(option.to_s) || value == option.to_s }
      end
      kept.empty? ? available : kept
    end

    # Sets the issue's field from the posted answer. A blank answer, or a
    # value that is not one of the choices, leaves Redmine's default.
    def apply(issue, answer)
      value = kind(issue) == :select ? chosen(issue, answer) : answer.to_s.strip
      return if value.blank?

      if custom_field?
        issue.custom_field_values = { attribute => value }
      else
        issue.public_send("#{attribute}=", value)
      end
    end

    private

    def chosen(issue, answer)
      values = choices(issue).map(&:last)
      picked = Array(answer).map(&:to_s).select { |value| values.include?(value) }
      multiple?(issue) ? picked : picked.first
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
      when 'done_ratio' then (0..100).step(Setting.issue_done_ratio_interval.to_i).map { |ratio| ["#{ratio} %", ratio] }
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
      custom_field(issue)&.possible_values_options(issue).to_a.map { |option| Array(option).values_at(0, -1) }
    end
  end
end
