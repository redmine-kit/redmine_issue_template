# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class IssueTemplatesControllerTest < Redmine::ControllerTest
    include RedmineIssueTemplate::TestHelper

    tests IssueTemplatesController
    fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
             :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
             :custom_fields_trackers, :issue_categories, :versions, :workflows

    def setup
      @project = enable_issue_templates
      @request.session[:user_id] = 2
    end

    def teardown
      remove_git_dirs
    end

    test 'the chooser lists the templates, the blank issue and the contact links' do
      import(github_files)
      get :index, params: { project_id: 'ecookbook', issue: { parent_issue_id: '1' } }
      assert_response :success
      assert_select 'h2', text: 'New issue'
      assert_select 'table.list.issue-templates tbody tr', 2
      link = '/projects/ecookbook/issues/new?issue%5Bparent_issue_id%5D=1&issue_template=bug_report'
      assert_select 'td.name a[href=?]', link, text: 'Bug Report'
      assert_select 'td.description', text: 'File a bug report.'
      assert_select 'p a.icon-add', text: 'Blank issue (maintainers only)'
      assert_select 'table.list.issue-template-contact-links td.name a[href=?]', 'https://bounty.github.com/'
    end

    test 'the blank issue link is hidden from users who cannot manage the templates' do
      import(github_files)
      @request.session[:user_id] = 3
      Role.find(2).add_permission!(:add_issues)
      get :index, params: { project_id: 'ecookbook' }
      assert_response :success
      assert_select 'p a.icon-add', 0
    end

    test 'the chooser needs Add issues and the module' do
      @request.session[:user_id] = nil
      with_settings login_required: '0' do
        Role.anonymous.remove_permission!(:add_issues)
        get :index, params: { project_id: 'ecookbook' }
        assert_response :redirect
      end

      @request.session[:user_id] = 2
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      get :index, params: { project_id: 'ecookbook' }
      assert_response :forbidden
    end

    test 'files can be added, edited and deleted in the settings' do
      post :create, params: { project_id: 'ecookbook',
                              issue_template_file: { path: 'bug.md', content: github_fixture('bug.md') } }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      file = IssueTemplateFile.find_by(project: @project, path: 'bug.md')
      assert_equal 'manual', IssueTemplateSource.find_by(project: @project).kind

      get :edit, params: { project_id: 'ecookbook', id: file.id }
      assert_response :success
      assert_select 'textarea#issue_template_file_content'

      patch :update,
            params: { project_id: 'ecookbook', id: file.id, issue_template_file: { path: '1-bug.md', content: 'x' } }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal %w[no_front_matter], IssueTemplateSource.find_by(project: @project).message_list.map(&:key)

      delete :destroy, params: { project_id: 'ecookbook', id: file.id }
      assert_empty IssueTemplateFile.where(project: @project)
    end

    test 'an invalid file name is refused' do
      post :create, params: { project_id: 'ecookbook', issue_template_file: { path: 'a/b.txt', content: 'x' } }
      assert_response :success
      assert_select '#errorExplanation'
    end

    test 'files from a repository are not edited in Redmine' do
      import(github_files, @project, source: 'repository')
      get :new, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
    end

    test 'Import now reads the repository' do
      git_repository(@project, '.redmine/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      post :sync, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal %w[bug.md], IssueTemplateFile.where(project: @project).pluck(:path)
    end

    test 'Import now without a repository' do
      post :sync, params: { project_id: 'onlinestore' }
      assert_response :forbidden

      @project.repository&.destroy
      post :sync, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal 'This project has no repository.', flash[:error]
    end

    test 'managing the templates needs the permission' do
      Role.find(1).remove_permission!(:manage_issue_templates)
      post :create, params: { project_id: 'ecookbook', issue_template_file: { path: 'a.md', content: 'x' } }
      assert_response :forbidden
    end
  end
end
