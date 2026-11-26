# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The plugin's MCP tools (redmine_kit_mcp's register_tool, when it is
    # installed): a project's templates the user may use, and a new issue made
    # from one as Redmine's form makes it (TemplateApplication, the browser's
    # way: the template's values, what it locks, its hidden fields, a form's
    # answers composed into the description and checked). create_issue of
    # redmine_kit_mcp follows the project's blank issue rule (McpHooks).
    module McpTools
      PROJECT = { type: 'string', description: 'Project identifier or id' }.freeze
      ANSWER = { type: %w[string array], items: { type: 'string' } }.freeze
      # A blank issue for a user who manages the templates (TemplateSet.blank_issue_allowed?), when the token has it
      # too, as Redmine's allowed_to? asks a token's scopes: a scope clients may ask for.
      MANAGE = %i[manage_issue_templates].freeze

      module_function

      # The skill that tells a client how to use the two tools (README.md, "MCP"): shown where both are offered
      # (Changes by AI clients: Save directly, and their scopes) to a user who may add issues in some project.
      SKILL = 'use-issue-templates'

      # Called in ActiveSupport.on_load(:redmine_kit_mcp), with RedmineKit::Mcp.
      def register(mcp)
        register_list(mcp)
        register_create(mcp)
        register_skill(mcp)
      end

      # Its folder is config/mcp_skills/<name> of the plugin's directory as Redmine found it (plugins/<id> or the
      # gem's: init.rb).
      def register_skill(mcp)
        directory = File.join(Redmine::Plugin.find(:redmine_kit_issue_template).directory, 'config/mcp_skills', SKILL)
        mcp.register_skill("issue_template.#{SKILL}",
                           directory: directory, permission: :add_issues,
                           tools: %w[issue_template.list_templates issue_template.create_issue])
      end

      def register_list(mcp)
        mcp.register_tool(
          'issue_template.list_templates',
          description: "List the issue templates the user may use in a project, with each form's fields and " \
                       'whether an issue without a template is allowed. Use a key with issue_template.create_issue.',
          input: { type: 'object', properties: { project: PROJECT }, required: %w[project],
                   additionalProperties: false },
          permission: :add_issues, optional_permissions: MANAGE, read_only: true
        ) { |call| list(call) }
      end

      def register_create(mcp)
        attributes = RedmineKit::Mcp::Tools::IssueChanges::ATTRIBUTES
        mcp.register_tool(
          'issue_template.create_issue',
          description: 'Create an issue in a project from one of its issue templates (keys from ' \
                       'issue_template.list_templates). The template sets its values and fields; a form takes its ' \
                       'answers by field ref (dropdowns and checkboxes by option value). Projects that require a ' \
                       'template refuse create_issue without one.',
          input: { type: 'object',
                   properties: { project: PROJECT, template: { type: 'string', description: 'The template key' },
                                 answers: { type: 'object', additionalProperties: ANSWER,
                                            description: "A form's answers by field ref" } }.merge(attributes),
                   required: %w[project template], additionalProperties: false },
          permission: :add_issues, optional_permissions: MANAGE, read_only: false, destructive: false
        ) { |call| create(call) }
      end

      def list(call)
        project = call.project!(call.args[:project])
        templates = usable(project, call.user)
        { project: { id: project.id, name: project.name },
          blank_issue_allowed: TemplateSet.blank_issue_allowed?(project, call.user),
          templates: templates.map { |template| template_data(template, project, call.user) } }
      end

      def usable(project, user)
        return [] unless project.module_enabled?(:issue_templates)

        TemplateSet.for(project).usable_for(project, user)
      end

      # The chooser's row and, for a form, its fields as the new UI's form gets
      # them (KitForm), from the issue the template makes.
      def template_data(template, project, user)
        issue = build(template, project, user, {})
        data = KitForm.answer(issue, ActionController::Parameters.new({}), user: user)[:data]
        row = data[:template]
        row.merge(fields: data[:elements].reject { |element| element[:type] == 'markdown' },
                  preset: data[:preset])
      end

      def create(call)
        project = call.project!(call.args[:project])
        template = template!(call, project)
        given = RedmineKit::Mcp::Tools::IssueChanges.attributes(call).except('notes', 'private_notes', 'lock_version')
        issue = build(template, project, call.user, given, answers: answers(template, call.args[:answers]))
        call.error!('No tracker is allowed for a new issue in this project') if issue.tracker.nil?
        save(issue, call)
        RedmineKit::Mcp::Serializer.issue(issue.reload, call.user).merge(template: template.key)
      end

      # A template the user may use in the project, or the tool's error that doesn't say which.
      def template!(call, project)
        key = call.args[:template].to_s
        template = usable(project, call.user).detect { |t| t.key == key }
        call.error!(RedmineKit::Mcp::ToolError.not_found('template', key).message) unless template
        template
      end

      # As MCP's create_issue saves: its hook (McpHooks: the blank issue rule), then Redmine's validations.
      def save(issue, call)
        Redmine::Hook.call_hook(:mcp_create_issue_before_save, issue: issue, user: call.user, arguments: call.args)
        saved = Issue.transaction { issue.save }
        call.error!(issue.errors.full_messages.join(', ')) unless saved
      end

      # A new issue of the user made from the template, as issues#new makes it
      # for the browser: the template's values for what isn't given, Redmine's
      # safe attributes for the user, then the template on the issue.
      def build(template, project, user, given, answers: {})
        application = TemplateApplication.new(template, project)
        issue = Issue.new(project: project, author: user)
        issue.start_date ||= user.today if Setting.default_issue_start_date_to_creation_date?
        # Redmine's own setter, with the user (Issue#safe_attributes=(attrs, user))
        issue.public_send(:safe_attributes=, application.restricted(application.with_defaults(given)), user)
        application.apply(issue, answers: answers)
      end

      # A form's answers of its own fields: a string or a list of strings each.
      def answers(template, given)
        return {} unless template.form? && given.is_a?(Hash)

        refs = template.fields.map(&:ref)
        given.to_h { |ref, value| [ref.to_s, value] }.slice(*refs).select do |_ref, value|
          value.is_a?(String) || (value.is_a?(Array) && value.all?(String))
        end
      end
    end
  end
end
