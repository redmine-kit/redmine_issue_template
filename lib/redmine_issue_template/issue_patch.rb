# frozen_string_literal: true

module RedmineIssueTemplate
  # A new issue made from a template: the fields the template hides are left
  # out of the form, the ones it requires are required as Redmine requires
  # fields, and an issue form's answers become the description.
  module IssuePatch
    def self.prepended(base)
      base.attr_reader :issue_template
      base.attr_accessor :issue_template_answers
      base.before_validation :apply_issue_template_links, on: :create
      base.before_validation :compose_issue_template_description, on: :create
      base.validate :validate_issue_template_answers, on: :create
    end

    # The template applies while the issue is new; edits later use
    # Redmine's own form.
    def issue_template=(template)
      @issue_template = template
      @issue_template_visibility = nil
      @issue_template_links = nil
      @workflow_rule_by_attribute = nil
    end

    def issue_template_active?
      new_record? && issue_template.present?
    end

    # { hidden: [...], required: [...], fixed: [...], linked: [...] }:
    # attribute names and custom field ids. Fixed: the values the template
    # sets, shown as text. Linked: set by a form's field (LinkedField).
    def issue_template_visibility
      return { hidden: [], required: [], fixed: [], linked: [] } unless issue_template_active? && project

      @issue_template_visibility ||= begin
        visibility = issue_template.options.visibility(project)
        visibility[:hidden] |= ['description'] if issue_template.form?
        visibility[:linked] = issue_template_links.map(&:attribute)
        visibility[:fixed] = IssueTemplateDefaults.new(issue_template, project).fixed.keys -
                             visibility[:hidden] - visibility[:linked]
        visibility
      end
    end

    def issue_template_links
      return [] unless issue_template_active?

      @issue_template_links ||= LinkedField.for(issue_template, project)
    end

    # The fields the form leaves out or shows as text.
    def issue_template_locked
      issue_template_visibility.values_at(:hidden, :fixed, :linked).inject(:|)
    end

    def safe_attribute_names(user = nil)
      names = super
      return names unless issue_template_active?

      # A form has its tracker and subject in its own box.
      names -= %w[tracker_id subject] if issue_template.form?
      names - issue_template_locked - ['project_id']
    end

    def editable_custom_field_values(user = nil)
      values = super
      return values unless issue_template_active?

      locked = issue_template_locked
      values.reject { |value| locked.include?(value.custom_field_id.to_s) }
    end

    # Redmine marks these fields as required and checks them.
    def required_attribute_names(user = nil)
      names = super
      return names unless issue_template_active?

      (names | issue_template_visibility[:required]) - issue_template_locked
    end

    def issue_template_composer
      BodyComposer.new(issue_template, issue_template_answers,
                       files: saved_attachments.map(&:filename), linked: issue_template_links.map(&:element))
    end

    private

    # On create, Redmine resets the custom fields the user can't edit to their
    # defaults. Fields the template hides or sets are not editable in the
    # form, but keep the value the template gives them.
    def force_default_value_on_noneditable_custom_fields
      return super unless issue_template_active?

      locked = issue_template_locked
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
