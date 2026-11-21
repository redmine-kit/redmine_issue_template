# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    class TemplateSetTest < ActiveSupport::TestCase
      include RedmineKit::IssueTemplate::TestHelper

      fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
               :issue_statuses, :enumerations

      BUG = "---\nname: Bug\nabout: a\ntype: Bug\n---\n"

      def setup
        @project = enable_issue_templates
        Role.find(2).add_permission!(:add_issues)
      end

      # The case => [config.yml's blank_issues_enabled, the user, what the
      # case changes, allowed]. jsmith (2) manages the templates; dlopper (3)
      # is a developer.
      CASES = {
        'blank issues on' => [true, 3, nil, true],
        'blank issues off' => [false, 3, nil, false],
        'blank issues off, for a user who manages the templates' => [false, 2, nil, true],
        'blank issues off, the module off' => [false, 3, :module_off, true],
        'blank issues off, no template the user may use' => [false, 3, :bug_tracker_refused, true]
      }.freeze

      CASES.each do |name, (enabled, user_id, change, allowed)|
        test "a blank issue: #{name}" do
          import({ 'bug.md' => BUG, 'config.yml' => "blank_issues_enabled: #{enabled}\n" }, @project)
          case change
          when :module_off
            @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
          when :bug_tracker_refused
            Role.find(2).tap { |role| role.set_permission_trackers(:add_issues, [2]) }.save!
          end
          project = Project.find(@project.id)
          user = User.find(user_id)
          assert_equal allowed, TemplateSet.blank_issue_allowed?(project, user)
          next if change == :module_off

          assert_equal allowed, TemplateSet.for(project).blank_issue_allowed?(project, user)
        end
      end
    end
  end
end
