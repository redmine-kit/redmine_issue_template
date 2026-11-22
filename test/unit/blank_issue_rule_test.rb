# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # The blank issue rule on the issue itself (IssuePatch#issue_template_missing?
    # and its validation): an issue of a checked path (issue_template_check) that
    # no template applies to is refused where blank issues are off; issues of
    # other paths (email, imports, the REST API) and copies are not.
    class BlankIssueRuleUnitTest < ActiveSupport::TestCase
      include RedmineKit::IssueTemplate::TestHelper

      fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
               :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
               :custom_fields_trackers, :custom_values, :issue_categories, :versions, :workflows, :issues

      def setup
        @project = enable_issue_templates
        Role.find(2).add_permission!(:add_issues)
        import('idea.md' => "---\nname: Idea\nabout: An idea\n---\nText\n",
               'config.yml' => "blank_issues_enabled: false\n")
        User.current = nil
      end

      def new_issue(author_id = 3, check: true)
        issue = Issue.new(project: @project, author: User.find(author_id), tracker_id: 1, subject: 'New',
                          status_id: 1, priority: IssuePriority.default || IssuePriority.first)
        issue.issue_template_check = check
        issue
      end

      test 'a checked issue without a template is refused with the message' do
        issue = new_issue
        assert_not issue.save
        assert_includes issue.errors[:base], 'Choose a template to create an issue.'
      end

      # who / where => saved
      {
        'an author who manages the templates' => [2, true],
        'a project with the module off' => [3, :module_off],
        'an issue of a path that is not checked (email, import, REST API)' => [3, :unchecked]
      }.each do |name, (author_id, how)|
        test "saved: #{name}" do
          @project.enabled_module_names = @project.enabled_module_names - ['issue_templates'] if how == :module_off
          issue = new_issue(author_id, check: how != :unchecked)
          assert issue.save, issue.errors.full_messages.inspect
        end
      end

      test 'a copy is made from its issue: not refused' do
        issue = Issue.new.copy_from(Issue.find(1))
        issue.project = @project
        issue.author = User.find(3)
        issue.issue_template_check = true
        assert issue.save, issue.errors.full_messages.inspect
      end

      test 'only a new issue: a later change of a checked issue is not refused' do
        issue = Issue.find(1)
        issue.issue_template_check = true
        issue.subject = 'Changed'
        assert issue.save
      end

      test "Redmine's mail handler creates issues where blank issues are off" do
        # from dlopper (a developer, who doesn't manage the templates)
        mail = File.read(Rails.root.join('test/fixtures/mail_handler/ticket_on_given_project.eml'))
                   .gsub('JSmith@somenet.foo', 'dlopper@somenet.foo')
        issue = MailHandler.receive(mail, issue: { project: 'ecookbook' })
        assert_kind_of Issue, issue
        assert_equal [3, 1], [issue.author_id, issue.project_id]
        assert issue.persisted?
      end
    end
  end
end
