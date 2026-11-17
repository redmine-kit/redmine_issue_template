# frozen_string_literal: true

module RedmineIssueTemplate
  # The new UI's part of "New issue" (redmine_kit_ui's docs/plugins-kit.md,
  # "The new issue's form"): the plugin's answer to the hook
  # kit_ui_new_issue_form, which redmine_kit_ui calls from Redmine's
  # issues#new answering /projects/:id/issues/form.json. The issue was built
  # by Redmine's build_new_issue_from_params with IssuesControllerPatch's
  # filters, as for Redmine's own form: the template of the request
  # (issue_template) applies and decides, as there, what the user may set
  # (IssuePatch, the one place). This class only says it to the app:
  #
  # - no template, and the project has templates: the chooser, as a step
  #   before the form (the templates the user may use, a blank issue when it
  #   is allowed, the contact links), as IssueTemplatesController#index;
  # - a template: its part of the form (its name and description, the values
  #   it sets, a form's fields with their answers as Redmine's form starts
  #   them, BodyComposer#value);
  # - a blank issue the user may create: the line that offers the chooser again.
  #
  # Nothing where the module is off or no template is usable: the app shows
  # Redmine's form alone. Texts are as written (Markdown): the app draws them
  # from the text.
  class KitForm
    PLUGIN = 'redmine_issue_template'
    NAME = 'template'
    # The labels of the values a template sets (issue_templates/_preset_values).
    LABELS = { 'priority_id' => :field_priority, 'category_id' => :field_category,
               'fixed_version_id' => :field_fixed_version, 'is_private' => :field_is_private }.freeze

    def self.answer(issue, params, user: User.current)
      new(issue, params, user).answer
    end

    def initialize(issue, params, user)
      @issue = issue
      @params = params
      @user = user
      @project = issue.project
    end

    def answer
      return unless @project&.module_enabled?(:issue_templates)
      return template_part if @issue.issue_template_active?

      chooser_part(set.usable_for(@project, @user))
    end

    # A template's row of the chooser (the form's step, the settings' preview).
    def chooser_row(template)
      { key: template.key, name: template.name, about: template.about.to_s, kind: kind(template),
        tracker: template.tracker(@project)&.name }
    end

    # The template's part of the form for an issue it applies to: the form's,
    # and the settings' preview (KitPreview).
    def template_data
      template_part[:data]
    end

    private

    # No template yet: the chooser, or a blank issue the user may create.
    def chooser_part(templates)
      return if templates.empty?
      return part(step: false, blank: true) if @params[:issue_template] == 'blank' && blank?

      part(step: true, templates: templates.map { |template| chooser_row(template) }, blank: blank?,
           contact_links: set.config.contact_links.map { |link| link.to_h.transform_values(&:to_s) })
    end

    def set
      @set ||= TemplateSet.for(@project)
    end

    def part(step:, **data)
      { plugin: PLUGIN, name: NAME, step: step, data: data }
    end

    # The chooser offers a blank issue as IssueTemplatesController#index does.
    def blank?
      set.config.blank_issues_enabled? || @user.allowed_to?(:manage_issue_templates, @project)
    end

    def kind(template)
      template.form? ? 'form' : 'markdown'
    end

    def template_part
      template = @issue.issue_template
      # the tracker and the subject are the new UI's own fields (IssuePatch)
      @issue.issue_template_host_fields = true
      part(step: false, template: chooser_row(template).merge(tracker: @issue.tracker&.name),
           preset: preset_values, elements: template.form? ? elements : [])
    end

    # The values the template sets, as text (issue_templates/_preset_values).
    # The tracker is the form's own field.
    def preset_values
      preset = @issue.issue_template_visibility[:preset]
      core = LABELS.filter_map do |name, label|
        next unless preset.include?(name)

        { label: ::I18n.t(label), value: core_value(name) }
      end
      core + @issue.custom_field_values.filter_map do |value|
        field = value.custom_field
        next unless preset.include?(field.id.to_s) && field.visible_by?(@project, @user)

        { label: field.name, value: field.format.formatted_custom_value(nil, value, false).to_s }
      end
    end

    def core_value(name)
      return ::I18n.t(@issue.is_private? ? :general_text_Yes : :general_text_No) if name == 'is_private'

      @issue.public_send(name.delete_suffix('_id'))&.name.to_s
    end

    # A form's elements as issue_templates/_form_fields draws them: the ones
    # the form leaves out dropped, each with what the form starts with.
    def elements
      composer = @issue.issue_template_composer
      (@issue.issue_template.elements - @issue.issue_template_dropped).map do |element|
        next { type: 'markdown', text: element.attributes['value'].to_s } if element.type == 'markdown'

        field(element).merge(value(element, composer))
      end
    end

    def field(element)
      { type: element.type, ref: element.ref, label: element.label,
        description: element.attributes['description'].to_s, placeholder: element.attributes['placeholder'].to_s,
        required: element.required? }
    end

    def value(element, composer)
      value = composer.value(element)
      case element.type
      when 'dropdown' then { multiple: element.multiple?, blank: !element.attributes.key?('default'),
                             options: indexed(element.options.map(&:to_s)), value: value }
      when 'checkboxes' then { options: checkbox_options(element), value: Array(value).map(&:to_s) }
      when 'upload' then { accept: element.accept }
      when 'link' then link(element, value)
      else { value: value.to_s, render: element.attributes['render'].present? }
      end
    end

    def indexed(labels)
      labels.each_with_index.map { |label, index| { value: index.to_s, label: label } }
    end

    def checkbox_options(element)
      element.checkbox_options.each_with_index.map do |option, index|
        { value: index.to_s, label: option[:label], required: option[:required] }
      end
    end

    # A field with a link (issue_templates/_linked_field): the kind of the
    # issue's field it sets, and its choices.
    def link(element, value)
      linked = @issue.issue_template_links.find { |candidate| candidate.element.equal?(element) }
      kind = linked ? linked.kind(@issue) : :select
      data = { kind: kind.to_s, multiple: linked&.multiple?(@issue) || false, value: value }
      return data unless kind == :select

      choices = linked ? linked.choices(@issue) : element.options.map { |option| [option.to_s, option.to_s] }
      data.merge(options: choices.map { |label, choice| { value: choice.to_s, label: label.to_s } })
    end
  end
end
