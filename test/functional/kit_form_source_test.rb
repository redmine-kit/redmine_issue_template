# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # The New issue sidebar's source (KitForm#sidebar) for templates imported
    # from the project's repository: the revision and its page only for a user
    # with view_changesets, the folder's page only with browse_repository, as
    # Redmine shows the repository's revisions and files.
    class KitFormSourceTest < Redmine::ControllerTest
      include RedmineKit::IssueTemplate::TestHelper

      tests IssuesController
      fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
               :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
               :custom_fields_trackers, :custom_values, :issue_categories, :versions, :workflows, :issues,
               :repositories

      REVISION = '0123456789abcdef0123456789abcdef01234567'

      def setup
        @project = enable_issue_templates
        Importer.import(@project, files: { 'feature.md' => "---\nname: Feature\nabout: An idea\n---\nText\n" },
                                  revision: REVISION, source: 'repository')
      end

      def source_for(user)
        KitForm.answer(Issue.new(project: @project, author: user), ActionController::Parameters.new({}),
                       user: user)[:data][:sidebar][:source]
      end

      # Developer (role 2, dlopper) adds issues without managing the templates.
      # permissions removed => [revision shown, folder's page shown]
      {
        'none' => [[], true, true],
        'view_changesets' => [%i[view_changesets], false, true],
        'browse_repository' => [%i[browse_repository], true, false],
        'both' => [%i[view_changesets browse_repository], false, false]
      }.each do |name, (removed, revision, folder_page)|
        test "the repository source without #{name}" do
          role = Role.find(2)
          removed.each { |permission| role.remove_permission!(permission) }
          source = source_for(User.find(3))
          assert_equal 'repository', source[:kind]
          assert_equal revision, source.key?(:revision), source.inspect
          assert_equal revision, source.key?(:revision_path), source.inspect
          assert_equal REVISION.first(8), source[:revision] if revision
          assert_equal folder_page, source.key?(:folder_path), source.inspect
          assert source.key?(:synced_at)
        end
      end

      test 'a disabled repository module hides the revision and the folder page' do
        @project.enabled_module_names = @project.enabled_module_names - ['repository']
        source = source_for(User.find(3))
        assert_equal 'repository', source[:kind]
        assert_not source.key?(:revision)
        assert_not source.key?(:folder_path)
      end
    end
  end
end
