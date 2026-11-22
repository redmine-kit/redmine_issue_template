# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # The templates a project uses (TemplateSource.provider_for, TemplateSet.for): its own, else those another project
    # shares with it as Redmine shares a version. Redmine's fixtures: eCookbook (1) with the subprojects 3, 4 and 5
    # (5 with its own subproject 6); OnlineStore (2) another tree.
    class TemplateSharingTest < ActiveSupport::TestCase
      include RedmineKit::IssueTemplate::TestHelper

      fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
               :issue_statuses, :enumerations

      BUG = "---\nname: Bug\nabout: a\n---\n"
      TASK = "---\nname: Task\nabout: b\n---\n"

      def setup
        [1, 2, 3, 4, 5, 6].each { |id| enable_issue_templates(Project.find(id)) }
      end

      def templates(project_id, sharing = nil)
        import({ 'bug.md' => project_id == 1 ? BUG : TASK }, Project.find(project_id))
        TemplateSource.find_by!(project_id:).update!(sharing:) if sharing
      end

      def provider(id)
        TemplateSource.provider_for(Project.find(id)).id
      end

      # [the project whose templates are shared, its sharing] => { project => whose templates it uses }
      CASES = {
        [1, 'none'] => { 1 => 1, 3 => 3, 6 => 6, 2 => 2 },
        [1, 'descendants'] => { 3 => 1, 5 => 1, 6 => 1, 2 => 2 },
        [1, 'hierarchy'] => { 3 => 1, 6 => 1, 2 => 2 },
        [1, 'tree'] => { 3 => 1, 6 => 1, 2 => 2 },
        [1, 'system'] => { 3 => 1, 2 => 1 },
        [3, 'descendants'] => { 1 => 1, 4 => 4 },
        [3, 'hierarchy'] => { 1 => 1, 4 => 4 },
        [3, 'tree'] => { 4 => 3, 6 => 3 }
      }.freeze

      CASES.each do |(owner, sharing), expected|
        test "a project #{owner} with templates shared #{sharing}" do
          templates(1) unless owner == 1
          templates(owner, sharing)
          expected.each { |project, used| assert_equal used, provider(project), "project #{project}" }
        end
      end

      test "a project's own templates come first, and the closest ancestor before the others" do
        templates(1, 'descendants')
        templates(5, 'descendants')
        templates(3)
        assert_equal 3, provider(3)
        assert_equal 5, provider(6)
        assert_equal 1, provider(4)
      end

      test 'a tree shared by a sibling: the first in Redmine order' do
        templates(3, 'tree')
        templates(4, 'tree')
        assert_equal 3, provider(5) # neither is an ancestor of 5: 3 (lft 6) comes before 4 (lft 8)
      end

      test 'an archived project shares nothing' do
        templates(1, 'descendants')
        Project.find(1).update_column(:status, Project::STATUS_ARCHIVED)
        assert_equal 3, provider(3)
      end

      test 'a closed project still shares' do
        templates(1, 'descendants')
        Project.find(1).update_column(:status, Project::STATUS_CLOSED)
        assert_equal 1, provider(3)
      end

      test 'a project with the module off shares nothing' do
        templates(1, 'descendants')
        Project.find(1).enabled_module_names = Project.find(1).enabled_module_names - ['issue_templates']
        assert_equal 3, provider(3)
      end

      test "the set a project uses is the provider's, its own set stays its own" do
        templates(1, 'descendants')
        assert_equal ['Bug'], TemplateSet.for(Project.find(3)).usable.map(&:name)
        assert_empty TemplateSet.own(Project.find(3)).usable
      end

      # the user => the sharings offered for project 3's templates (Version#allowed_sharings' rule)
      test 'the sharings a user may choose' do
        templates(1)
        templates(3)
        source = TemplateSource.find_by!(project_id: 3)
        Role.find(1).add_permission!(:manage_issue_templates)
        assert_equal TemplateSource::SHARINGS, source.allowed_sharings(User.find(1))
        assert_equal %w[none descendants hierarchy tree], source.allowed_sharings(User.find(2)) # Manager of 1 (root)
        Member.where(user_id: 2, project_id: 1).destroy_all
        assert_equal %w[none descendants], TemplateSource.find_by!(project_id: 3).allowed_sharings(User.find(2).reload)
      end

      test 'a sharing outside the values is refused' do
        templates(1)
        source = TemplateSource.find_by!(project_id: 1)
        source.sharing = 'everyone'
        assert_not source.valid?
        assert_includes source.errors.attribute_names, :sharing
      end
    end
  end
end
