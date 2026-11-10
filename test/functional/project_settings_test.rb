# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class ProjectSettingsTest < Redmine::ControllerTest
    include RedmineIssueTemplate::TestHelper

    tests ProjectsController
    fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
             :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
             :custom_fields_trackers, :issue_categories, :versions

    def setup
      @project = enable_issue_templates
      @request.session[:user_id] = 2
    end

    test 'the tab lists the files with their errors and warnings' do
      import(github_files.merge('broken.yml' => "name: x\n"))
      get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
      assert_response :success
      assert_select '#tab-issue_templates'
      assert_select 'table.list.issue-template-files tbody tr', 4
      assert_select 'table.list.issue-template-files td.name', text: 'broken.yml'
      assert_select 'table.list.issue-template-files td', text: 'Template chooser', count: 0
      assert_select '#errorExplanation li', text: 'broken.yml: description cannot be blank'
      assert_select 'div.warning li', text: /octo-org/
      assert_select '#tab-content-issue_templates p a.icon-add', text: 'New file'
      assert_select '#tab-content-issue_templates p a.icon-import', text: 'Import'
      assert_select '#tab-content-issue_templates p a.icon-help[href=?]', "#{RedmineIssueTemplate::DOCS_URL}format"
      assert_select 'table.issue-template-source', 0
    end

    test 'files from a repository are shown read-only' do
      import(github_files, @project, source: 'repository')
      get :settings, params: { id: 'ecookbook', tab: 'issue_templates' }
      assert_select '#tab-content-issue_templates p a.icon-add', 0
      assert_select '#tab-content-issue_templates td.buttons a', 0
      assert_select 'table.issue-template-source td.name', text: 'Repository'
      assert_select 'table.issue-template-source td', text: %r{\A\.(github|redmine)/ISSUE_TEMPLATE\z}
      assert_select 'table.issue-template-source td.name', text: 'Updated'
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
