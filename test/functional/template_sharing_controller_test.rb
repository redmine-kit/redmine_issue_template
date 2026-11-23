# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # 共有 of a project's templates (PATCH /projects/:id/issue_templates/sharing): a value the user may choose is saved;
    # any other value, shape or user is refused, and nothing changes. The settings tab shows it, and 共有元 where the
    # project uses another project's templates.
    class TemplateSharingControllerTest < Redmine::ControllerTest
      include RedmineKit::IssueTemplate::TestHelper

      tests TemplatesController
      fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
               :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
               :custom_fields_trackers, :issue_categories, :versions, :workflows

      def setup
        @project = enable_issue_templates
        import('bug.md' => "---\nname: Bug\nabout: a\n---\n")
        as_user(User.find(2))
      end

      # The user of the request: the new UI's JSON is a kit request with the browser's session, which redmine_kit_ui
      # finds (KitSettingsTest); Redmine's own pages use the session.
      def as_user(user)
        TemplatesController.any_instance.stubs(:find_current_user).returns(user)
      end

      def sharing
        TemplateSource.find_by!(project_id: 1).sharing
      end

      # value sent, the user => saved
      CASES = {
        'descendants, by a manager' => ['descendants', 2, true],
        'tree, by a manager of the root' => ['tree', 2, true],
        'system, by a manager' => ['system', 2, false],
        'system, by an administrator' => ['system', 1, true],
        'an unknown value' => ['everyone', 2, false],
        'a list' => [%w[tree], 2, false],
        'a mapping' => [{ 'a' => 'tree' }, 2, false],
        'nothing' => [nil, 2, false]
      }.freeze

      CASES.each do |name, (value, user, saved)|
        test "共有: #{name}" do
          as_user(User.find(user))
          patch :sharing, params: { project_id: 'ecookbook', sharing: value }, format: :json
          assert_response saved ? :no_content : :unprocessable_content
          assert_equal saved ? value : 'none', sharing
        end
      end

      test 'refused without manage_issue_templates, and where the module is off' do
        as_user(User.find(3))
        patch :sharing, params: { project_id: 'ecookbook', sharing: 'descendants' }, format: :json
        assert_response :forbidden
        as_user(User.find(2))
        @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
        patch :sharing, params: { project_id: 'ecookbook', sharing: 'descendants' }, format: :json
        assert_response :forbidden
        assert_equal 'none', sharing
      end

      test "Redmine's page: saved with its notice, back to the tab" do
        patch :sharing, params: { project_id: 'ecookbook', sharing: 'descendants' }
        assert_redirected_to '/projects/ecookbook/settings/issue_templates'
        assert_equal 'descendants', sharing
      end

      test "the settings' JSON: the value, the values the user may choose, and 共有元" do
        TemplateSource.find_by!(project_id: 1).update!(sharing: 'descendants')
        enable_issue_templates(Project.find(3))
        Member.create!(principal: User.find(2), project: Project.find(3), role_ids: [1])
        get :files, params: { project_id: 'subproject1' }, format: :json
        data = response.parsed_body['issue_templates']
        provider = { 'name' => 'eCookbook', 'identifier' => 'ecookbook' }
        assert_equal ['none', %w[none descendants hierarchy tree], provider],
                     data.values_at('sharing', 'sharings', 'provider')
        # the provider's templates the project uses, read-only (no id: they aren't the project's files)
        assert_equal [{ 'path' => 'bug.md', 'kind' => 'markdown', 'name' => 'Bug', 'tracker' => nil, 'form' => false }],
                     data['shared_files']
        assert_empty data['files']
      end
    end
  end
end
