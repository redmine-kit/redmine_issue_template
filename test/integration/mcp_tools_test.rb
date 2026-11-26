# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # MCP (redmine_kit_mcp): its create_issue follows the blank issue rule
    # (McpHooks), and the plugin's tools list a project's templates and make an
    # issue from one as the browser does (McpTools, TemplateApplication). Run
    # with redmine_kit_mcp and redmine_kit_ui (bin/test's MCP run); skipped
    # without them. The developer (dlopper, role 2) adds issues and doesn't
    # manage templates.
    class McpToolsTest < Redmine::IntegrationTest
      MCP = Redmine::Plugin.installed?(:redmine_kit_mcp)

      include RedmineKit::IssueTemplate::TestHelper
      include RedmineKit::Mcp::TestHelper if MCP

      fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :trackers,
               :projects_trackers, :enabled_modules, :issue_statuses, :enumerations, :custom_fields,
               :custom_fields_projects, :custom_fields_trackers, :custom_values, :issue_categories, :versions,
               :workflows, :issues

      SCOPES = %w[view_project view_issues add_issues].freeze

      IDEA = <<~MARKDOWN
        ---
        name: Idea
        about: An idea
        title: "[Idea] "
        type: Bug
        priority: High
        ---
        The idea
      MARKDOWN

      def setup
        skip 'redmine_kit_mcp is not installed' unless MCP

        Setting.rest_api_enabled = '1'
        Setting.host_name = 'www.example.com'
        # Operations allowed to AI clients: Create issues, so that both create_issue tools are offered (off by default)
        create = RedmineKit::Mcp::OperationRegistry.find(:create_issues).setting
        Setting.plugin_redmine_kit_mcp = RedmineKit::Mcp::Settings::DEFAULTS.merge(create => '1')
        @project = enable_issue_templates
        Role.find(2).add_permission!(:add_issues)
      end

      def blank_issues(enabled)
        import('idea.md' => IDEA, 'bug_report.yml' => github_fixture('bug_report.yml'),
               'config.yml' => "blank_issues_enabled: #{enabled}\n")
      end

      def call(name, args, user_id: 3)
        mcp_call(name, args, token: mcp_token(User.find(user_id), scopes: SCOPES))
      end

      # tool, blank issues enabled => saved
      [
        ['create_issue', false, false], ['create_issue', true, true],
        ['issue_template.create_issue', false, true], ['issue_template.create_issue', true, true]
      ].each do |tool, enabled, saved|
        test "#{tool}, blank issues #{enabled ? 'on' : 'off'}: #{saved ? 'saved' : 'refused'}" do
          blank_issues(enabled)
          args = { project: 'ecookbook', subject: 'From MCP' }
          args[:template] = 'idea' if tool.start_with?('issue_template.')
          count = Issue.count
          answer = call(tool, args)
          assert_equal count + (saved ? 1 : 0), Issue.count, answer.json.inspect
          if saved
            assert_not answer.error?
          else
            assert answer.error?
            assert_includes answer.text, 'Choose a template to create an issue.'
          end
        end
      end

      # redmine_kit_mcp's operations AI clients may do => the tools and the skill. Both create_issue tools are the
      # operation Create issues: without it the clients get list_templates only, and not the skill, which needs both
      # of the plugin's tools. (Save drafts is Redmine Kit Drafts' operation, which this run doesn't install.)
      SKILL = 'skill://plugins/issue_template/use-issue-templates/SKILL.md'
      CREATING = %w[create_issue issue_template.create_issue issue_template.list_templates].freeze

      test 'the skill use-issue-templates as registered: its tools exist, its SKILL.md is valid' do
        assert_mcp_skill_contract('issue_template.use-issue-templates')
      end

      {
        'Create issues' => [%i[create_issues], CREATING],
        'Read-only' => [nil, %w[issue_template.list_templates]]
      }.each do |name, (operations, offered)|
        test "#{name}: #{offered.join(', ')}, the skill #{offered.size > 1 ? 'served' : 'hidden'}" do
          blank_issues(true)
          check = lambda do
            token = mcp_token(User.find(3), scopes: SCOPES)
            assert_equal offered, mcp_list(token: token) & CREATING
            if offered.include?('issue_template.create_issue')
              assert_equal 'use-issue-templates', assert_mcp_skill_served(SKILL, token: token).frontmatter['name']
            else
              assert_mcp_skill_hidden(SKILL, token: token)
              count = Issue.count
              assert call('issue_template.create_issue', { project: 'ecookbook', template: 'idea' }).error?
              assert_equal count, Issue.count
            end
          end
          operations ? with_mcp_operations(*operations, &check) : with_mcp_read_only(&check)
        end
      end

      test 'the skill is hidden from a token without the scope add_issues' do
        assert_mcp_skill_hidden(SKILL, token: mcp_token(User.find(3), scopes: SCOPES - %w[add_issues]))
      end

      test 'the skill is hidden from a user who may add issues in no project, though the token has the scope' do
        Role.find_each { |role| role.remove_permission!(:add_issues) }
        assert_mcp_skill_hidden(SKILL, token: mcp_token(User.find(3), scopes: SCOPES))
      end

      # A manager's blank issue needs the scope too, as Redmine's allowed_to? asks a token's scopes.
      { 'with the scope manage_issue_templates' => [SCOPES + %w[manage_issue_templates], true],
        'without it' => [SCOPES, false] }.each do |name, (scopes, saved)|
        test "create_issue by a user who manages the templates, #{name}: #{saved ? 'saved' : 'refused'}" do
          blank_issues(false)
          answer = mcp_call('create_issue', { project: 'ecookbook', subject: 'Blank' },
                            token: mcp_token(User.find(2), scopes: scopes))
          assert_equal !saved, answer.error?, answer.json.inspect
        end
      end

      test "issue_template.create_issue: the template's values, as the browser's form starts with them" do
        blank_issues(false)
        answer = call('issue_template.create_issue', { project: 'ecookbook', template: 'idea', priority_id: 4 })
        assert_not answer.error?, answer.json.inspect
        issue = Issue.find(answer.structured[:id])
        # the tracker and the priority are the template's (preset: the request can't change them)
        assert_equal ['[Idea] ', 'The idea', 1, IssuePriority.find_by(name: 'High').id, 3],
                     [issue.subject, issue.description.strip, issue.tracker_id, issue.priority_id, issue.author_id]
        assert_equal 'idea', answer.structured[:template]
      end

      test "issue_template.create_issue: a form's answers become the description, its required ones checked" do
        blank_issues(false)
        answers = { 'what-happened' => 'It broke', 'version' => '1', 'terms' => ['0'] }
        answer = call('issue_template.create_issue', { project: 'ecookbook', template: 'bug_report',
                                                       subject: 'Broken', answers: answers })
        assert_not answer.error?, answer.json.inspect
        description = Issue.find(answer.structured[:id]).description
        assert_includes description, 'It broke'
        assert_includes description, '1.0.3 (Edge)'

        count = Issue.count
        answer = call('issue_template.create_issue', { project: 'ecookbook', template: 'bug_report',
                                                       subject: 'Broken', answers: { 'what-happened' => '' } })
        assert answer.error?
        assert_includes answer.text, 'What happened?'
        assert_equal count, Issue.count
      end

      test 'issue_template.create_issue: an unknown template, or one of a project the user may not add to' do
        blank_issues(false)
        assert_mcp_tool_error('issue_template.create_issue', { project: 'ecookbook', template: 'nope' },
                              token: mcp_token(User.find(3), scopes: SCOPES))
        Role.find(2).remove_permission!(:add_issues)
        assert_mcp_tool_error('issue_template.create_issue', { project: 'ecookbook', template: 'idea' },
                              token: mcp_token(User.find(3), scopes: SCOPES))
      end

      test 'issue_template.list_templates: the keys, the fields of a form, whether a blank issue is allowed' do
        blank_issues(false)
        answer = call('issue_template.list_templates', { project: 'ecookbook' })
        assert_not answer.error?, answer.json.inspect
        result = answer.structured
        assert_equal false, result[:blank_issue_allowed]
        assert_equal %w[bug_report idea], result[:templates].pluck(:key).sort
        form = result[:templates].detect { |template| template[:key] == 'bug_report' }
        version = form[:fields].detect { |field| field[:ref] == 'version' }
        assert_equal [{ value: '0', label: '1.0.2 (Default)' }, { value: '1', label: '1.0.3 (Edge)' }],
                     version[:options]
      end
    end
  end
end
