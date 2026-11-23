# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    class ProjectSettingsTest < Redmine::ControllerTest
      include RedmineKit::IssueTemplate::TestHelper

      tests ProjectsController
      fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
               :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
               :custom_fields_trackers, :issue_categories, :versions

      def setup
        @project = enable_issue_templates
        @request.session[:user_id] = 2
      end

      test "共有 with the values the user may choose, and 共有元 where another project's templates are used" do
        import({ 'bug.md' => "---\nname: Bug\nabout: a\n---\n" })
        TemplateSource.find_by!(project_id: 1).update!(sharing: 'descendants')
        enable_issue_templates(Project.find(3))
        Member.create!(principal: User.find(2), project: Project.find(3), role_ids: [1])
        get :settings, params: { id: 'subproject1', tab: 'issue_templates' }
        assert_response :success
        assert_select 'select#issue_template_sharing option', 4
        assert_select 'select#issue_template_sharing option[selected]', text: 'Not shared'
        assert_select 'p.issue-template-provider label', text: 'Shared from'
        assert_select 'p.issue-template-provider a', text: 'eCookbook'
        # the provider's templates the project uses, read-only, with their project; no empty state
        assert_select 'table.issue-template-files.shared tr.shared td.name', text: 'bug.md'
        assert_select 'table.issue-template-files.shared tr.shared td.description', text: 'Bug'
        assert_select 'table.issue-template-files.shared td.project a', text: 'eCookbook'
        assert_select 'table.issue-template-files.shared td.buttons', 0
        assert_select '#tab-content-issue_templates p.nodata', 0
        get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
        assert_select 'p.issue-template-provider', 0
        assert_select 'select#issue_template_sharing option[selected]', text: 'With subprojects'
      end

      test 'the tab lists the files and says when some can\'t be used' do
        import(github_files.merge('broken.yml' => "name: x\n"))
        get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
        assert_response :success
        assert_select '#tab-issue_templates'
        assert_select 'table.list.issue-template-files tbody tr', 4
        assert_select 'table.list.issue-template-files td.name', text: 'broken.yml'
        assert_select 'fieldset.issue-template-chooser-settings legend', text: 'Template chooser'
        # The problems themselves are on the file's page.
        assert_select '#errorExplanation', text: /Some templates cannot be used because they have errors/
        assert_select '#errorExplanation li', 0
        assert_select 'div.warning li', 0
        assert_select '#tab-content-issue_templates p a.icon-add', text: 'New template'
        assert_select '#tab-content-issue_templates p a.icon-import', text: 'Import'
        assert_select '#tab-content-issue_templates p a.icon-help[href=?]', "#{RedmineKit::IssueTemplate::DOCS_URL}format"
        assert_select 'table.issue-template-source', 0
        # config.yml's settings, editable: its two links and a row to add one.
        assert_select 'input[type=checkbox][name=blank_issues_enabled]:not([checked]):not([disabled])'
        assert_select 'table.issue-template-contact-links tbody tr', 3
        assert_select 'input[name=?][value=?]', 'contact_links[][name]', 'GitHub Community Support'
      end

      test 'files from a repository are shown read-only' do
        import(github_files, @project, source: 'repository')
        get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
        assert_select '#tab-content-issue_templates p a.icon-add', 0
        assert_select '#tab-content-issue_templates td.buttons a', 0
        assert_select 'table.issue-template-source td.name', text: 'Repository'
        assert_select 'table.issue-template-source td', text: %r{\A\.(github|redmine)/ISSUE_TEMPLATE\z}
        assert_select 'table.issue-template-source td.name', text: 'Updated'
        # config.yml is the repository's: shown, not edited.
        assert_select 'input[type=checkbox][name=blank_issues_enabled][disabled=disabled]'
        assert_select 'table.issue-template-contact-links tbody tr', 2
        assert_select 'fieldset.issue-template-chooser-settings ~ input[type=submit]', 0
        # 共有 is the source's, whatever the files come from: its own form saves it
        assert_select 'form[action=?] input[type=submit]', '/projects/ecookbook/issue_templates/sharing', 1
      end

      test 'the tab warns when the text formatting is not CommonMark' do
        with_settings text_formatting: 'textile' do
          get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
          assert_select 'p.warning', text: 'Text formatting is not CommonMark Markdown (GitHub Flavored).'
        end
      end

      test 'the tab needs the permission' do
        Role.find(1).remove_permission!(:manage_issue_templates)
        get :settings, params: { id: 'ecookbook' }
        assert_select '#tab-issue_templates', 0
      end
    end
  end
end
