# frozen_string_literal: true

module RedmineIssueTemplate
  # A new issue made from a template: the fields the template hides are left
  # out of the form, the ones it requires are required as Redmine requires
  # fields, and an issue form's answers become the description.
  module IssuePatch
    include RedmineRules

    # The links apply before Redmine's own callbacks (default_assign takes the
    # linked category's assignee) and the description is composed after them.
    def self.prepended(base)
      base.attr_reader :issue_template
      base.attr_accessor :issue_template_answers
      base.attr_writer :issue_template_defaults
      base.before_validation :apply_issue_template_links, on: :create, prepend: true
      base.before_validation :compose_issue_template_description, on: :create
      base.validate :validate_issue_template_answers, on: :create
    end

    def issue_template=(template)
      @issue_template = template
      @issue_template_defaults = nil
      @issue_template_visibility = nil
      @issue_template_links = nil
      # Redmine caches the workflow's rules, read with the fields before.
      @workflow_rule_by_attribute = nil
    end

    # The template applies while the issue is new; edits later use
    # Redmine's own form.
    def issue_template_active?
      new_record? && issue_template.present?
    end

    # The template's values for the project, given by the controller for the
    # request, or resolved here.
    def issue_template_defaults
      @issue_template_defaults ||= IssueTemplateDefaults.new(issue_template, project)
    end

    # The one place that decides what the template does to the form:
    # { hidden: [...], required: [...], preset: [...], linked: [...] },
    # attribute names and custom field ids. Hidden: left out (fields Redmine
    # requires and the template doesn't fill stay shown). Preset: the
    # template's values, shown as text. Linked: set by a form's field.
    # Built once the tracker and status are set (build_new_issue_from_params).
    def issue_template_visibility
      return { hidden: [], required: [], preset: [], linked: [] } unless issue_template_active? && project

      @issue_template_visibility ||= begin
        visibility = issue_template.options.visibility(project)
        visibility[:hidden] -= issue_template_unfilled(visibility[:hidden])
        visibility[:hidden] |= ['description'] if issue_template.form?
        visibility[:linked] = issue_template_links.map(&:attribute)
        visibility[:preset] = issue_template_defaults.preset.keys - visibility[:hidden] - visibility[:linked]
        visibility
      end
    end

    def issue_template_links
      return [] unless issue_template_active?

      @issue_template_links ||= LinkedField.for(self)
    end

    def issue_template_dropped
      issue_template_active? ? LinkedField.dropped(issue_template, issue_template_links) : []
    end

    # The fields not in Redmine's part of the form: left out or shown as text.
    def issue_template_not_in_form
      issue_template_visibility.values_at(:hidden, :preset, :linked).inject(:|)
    end

    def safe_attribute_names(user = nil)
      names = super
      return names unless issue_template_active?

      # A form has its tracker and subject in its own box.
      names -= %w[tracker_id subject] if issue_template.form?
      names - issue_template_not_in_form - ['project_id']
    end

    def editable_custom_field_values(user = nil)
      values = super
      return values unless issue_template_active?

      locked = issue_template_not_in_form
      values.reject { |value| locked.include?(value.custom_field_id.to_s) }
    end

    # Redmine marks these fields as required and checks them.
    # The template's required fields that the user can set. The fields it
    # hides, sets or links are still checked by Redmine's own rules.
    def required_attribute_names(user = nil)
      names = super
      return names unless issue_template_active?

      required = issue_template_visibility[:required]
      names | required.select { |name| issue_template_settable?(name, user) }
    end

    # Redmine checks the custom fields the form shows; those the template
    # hides, sets or links are checked as well.
    def validate_custom_field_values
      return super unless issue_template_active?

      redmine_method(:editable_custom_field_values).call(author).each(&:validate_value)
    end

    def issue_template_composer
      BodyComposer.new(issue_template, issue_template_answers,
                       files: saved_attachments.map(&:filename), linked: issue_template_links.map(&:element),
                       dropped: issue_template_dropped)
    end

    private

    # On create, Redmine resets the custom fields the user can't edit to their
    # defaults. Fields the template hides, sets or links are not editable in
    # the form, but keep their value when Redmine lets the user set them.
    def force_default_value_on_noneditable_custom_fields
      return super unless issue_template_active?

      locked = issue_template_not_in_form.select { |id| issue_template_settable?(id) }
      kept = custom_field_values.select { |value| locked.include?(value.custom_field_id.to_s) }
                                .to_h { |value| [value, value.value] }
      super
      kept.each { |field_value, value| field_value.value = value }
    end

    def apply_issue_template_links
      answers = (issue_template_answers || {}).to_h.transform_keys(&:to_s)
      issue_template_links.each { |link| link.apply(self, answers[link.element.ref]) }
    end

    def compose_issue_template_description
      return unless issue_template_active? && issue_template.form?

      self.description = issue_template_composer.compose
    end

    def validate_issue_template_answers
      return unless issue_template_active? && issue_template.form?

      issue_template_composer.problems.each do |element, problem|
        message = case problem
                  when :too_short then ::I18n.t('activerecord.errors.messages.too_short', count: element.min_length)
                  when :unchecked then ::I18n.t(:issue_template_error_unchecked)
                  else ::I18n.t('activerecord.errors.messages.blank')
                  end
        errors.add(:base, "#{element.label}#{::I18n.t(:issue_template_error_separator)}#{message}")
      end
    end
  end
end
