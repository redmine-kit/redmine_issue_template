# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The preview of a template file in the new UI's settings (the tab's
    # プレビュー, and the file form's, from the text as typed): what users see
    # with the file, as TemplatesController#build_preview gives Redmine's
    # page. The file is read with the project's other files (names and ids
    # must be unique) and checked as an import checks it; nothing is saved.
    #
    # - messages: the file's errors and warnings, in Redmine's sentences;
    # - preview: nil when the file has errors (it is left out of the chooser);
    #   for config.yml the chooser it makes (the usable templates, a blank
    #   issue, the contact links); for a template its row of the chooser and
    #   the new issue's form with it: the issue's tracker, subject and
    #   description as the form starts them, and the template's part
    #   (KitForm#template_data, the same data the new issue's form gets).
    class KitPreview
      # The chooser a set of files makes (the preview of config.yml; the
      # settings' tab for the project's files as saved), as the new issue's
      # step draws it: the usable templates, a blank issue, the contact links.
      def self.chooser(set, project, user = User.current)
        form = KitForm.new(Issue.new(project: project), {}, user)
        config = set.config
        { templates: set.usable.map { |template| form.chooser_row(template) }, blank: config.blank_issues_enabled?,
          contact_links: config.contact_links.map { |link| link.to_h.transform_values(&:to_s) } }
      end

      # The preview of a file as typed (not saved): its own errors first (its
      # name, its length), as Redmine's form shows them; then, when it has
      # none, the template's messages and what users would see.
      def self.typed(project, file)
        return new(project, file).to_h if file.valid?

        { messages: file.errors.full_messages.map { |text| { level: 'error', text: text } }, preview: nil }
      end

      def initialize(project, file, user: User.current)
        @project = project
        @file = file
        @user = user
      end

      def to_h
        set = @file.parse_with_others
        found = set.messages.select { |message| message.path == @file.path }
        { messages: found.map { |message| { level: message.error? ? 'error' : 'warning', text: message.text } },
          preview: found.any?(&:error?) ? nil : preview(set) }
      end

      private

      def preview(set)
        return config_preview(set) if Parser.kind(@file.path) == :config

        template = set.templates.detect { |candidate| candidate.path == @file.path }
        template && template_preview(template)
      end

      def config_preview(set)
        { kind: 'config', chooser: self.class.chooser(set, @project, @user) }
      end

      def template_preview(template)
        issue = IssueTemplateDefaults.new(template, @project).new_issue(@user)
        { kind: 'template', chooser_row: KitForm.new(Issue.new(project: @project), {}, @user).chooser_row(template),
          issue: { tracker: issue.tracker&.name, subject: issue.subject.to_s,
                   description: template.form? ? nil : issue.description.to_s },
          section: KitForm.new(issue, {}, @user).template_data }
      end
    end
  end
end
