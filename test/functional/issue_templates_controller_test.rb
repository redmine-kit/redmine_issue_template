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
      assert_select 'p a.icon-add', text: 'Blank issue'
      assert_select 'h3', text: 'Other contacts'
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

      get :show, params: { project_id: 'ecookbook', id: file.id }
      assert_select 'div.contextual a.icon-edit'
      assert_select 'div.box pre', text: /name: 🐞 Bug/

      patch :update,
            params: { project_id: 'ecookbook', id: file.id, issue_template_file: { path: '1-bug.md', content: 'x' } }
      assert_response :success
      assert_select '#errorExplanation li', text: '1-bug.md: front matter cannot be blank'
      assert_equal 'bug.md', file.reload.path

      patch :update, params: { project_id: 'ecookbook', id: file.id,
                               issue_template_file: { path: '1-bug.md', content: github_fixture('bug.md') } }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal '1-bug.md', file.reload.path

      delete :destroy, params: { project_id: 'ecookbook', id: file.id }
      assert_empty IssueTemplateFile.where(project: @project)
    end

    test 'an invalid file name is refused' do
      post :create, params: { project_id: 'ecookbook', issue_template_file: { path: 'a/b.txt', content: 'x' } }
      assert_response :success
      assert_select '#errorExplanation'
    end

    test 'preview shows the chooser and the form without saving' do
      content = "---\nname: Feature\nabout: Ask\ntitle: '[Feature] '\ntype: Feature request\n" \
                "fields:\n  estimated_hours: hidden\n  due_date: required\n---\nThe idea\n"
      post :create, params: { project_id: 'ecookbook', preview: 'Preview',
                              issue_template_file: { path: 'feature.md', content: content } }
      assert_response :success
      assert_empty IssueTemplateFile.where(project: @project)
      assert_select 'textarea#issue_template_file_content', text: /name: Feature/
      assert_select 'h3', text: 'Preview'
      assert_select '.issue-template-preview[inert]' do
        assert_select 'table.issue-templates td.name', text: 'Feature'
        assert_select 'table.issue-templates td', text: 'Feature request'
        assert_select 'input#issue_subject[value=?]', '[Feature] '
        assert_select 'textarea#issue_description', text: /The idea/
        assert_select 'input#issue_estimated_hours', 0
        assert_select 'label[for=issue_due_date] span.required'
      end
    end

    test 'preview of a YAML form shows its fields' do
      file = { path: 'bug_report.yml', content: github_fixture('bug_report.yml') }
      post :create, params: { project_id: 'ecookbook', preview: 'Preview', issue_template_file: file }
      assert_select '.issue-template-preview' do
        assert_select 'textarea[name=?]', 'issue_template_answers[what-happened]'
        assert_select 'textarea#issue_description', 0
      end
    end

    test 'preview of a file with errors shows the errors' do
      post :create, params: { project_id: 'ecookbook', preview: 'Preview',
                              issue_template_file: { path: 'form.yml', content: "name: Form\n" } }
      assert_select '#errorExplanation li', text: 'form.yml: description cannot be blank'
      assert_select '.issue-template-preview', 0
    end

    test 'preview of config.yml shows the chooser' do
      import(github_files, @project, source: 'repository')
      file = IssueTemplateFile.find_by(project: @project, path: 'config.yml')
      get :show, params: { project_id: 'ecookbook', id: file.id }
      assert_select '.issue-template-preview' do
        assert_select 'table.issue-templates tbody tr', 2
        assert_select 'h3', text: 'Other contacts'
        assert_select 'table.issue-template-contact-links td.name', text: 'GitHub Community Support'
      end
    end

    test 'a file with errors is not saved' do
      post :create, params: { project_id: 'ecookbook',
                              issue_template_file: { path: 'form.yml', content: "name: Form\nbody: []\n" } }
      assert_response :success
      assert_select '#errorExplanation li', text: 'form.yml: description cannot be blank'
      assert_select '#errorExplanation li', text: 'form.yml: body cannot be blank'
      assert_empty IssueTemplateFile.where(project: @project)
    end

    test 'files from a repository are shown read-only and not edited in Redmine' do
      import(github_files, @project, source: 'repository', folder: '.github/ISSUE_TEMPLATE')
      file = IssueTemplateFile.find_by(project: @project, path: 'bug.md')
      content = file.content

      get :show, params: { project_id: 'ecookbook', id: file.id }
      assert_response :success
      assert_select 'h2', text: /bug.md/
      assert_select 'table.issue-template-source td', text: '.github/ISSUE_TEMPLATE'
      assert_select 'div.box pre', text: /name: 🐞 Bug/
      assert_select 'div.contextual', 0
      assert_select '.issue-template-preview table.issue-templates td.name', text: '🐞 Bug'

      get :new, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      get :edit, params: { project_id: 'ecookbook', id: file.id }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      patch :update,
            params: { project_id: 'ecookbook', id: file.id, issue_template_file: { path: 'x.md', content: 'x' } }
      assert_equal 'Edit the templates in the repository.', flash[:error]
      delete :destroy, params: { project_id: 'ecookbook', id: file.id }
      assert_equal ['bug.md', content], file.reload.slice(:path, :content).values
    end

    test 'Import reads the repository' do
      git_repository(@project, '.redmine/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      post :sync, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal %w[bug.md], IssueTemplateFile.where(project: @project).pluck(:path)
    end

    test 'Import without a repository' do
      post :sync, params: { project_id: 'onlinestore' }
      assert_response :forbidden

      @project.repository&.destroy
      post :sync, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
      assert_equal 'Repository not found', flash[:error]
    end

    test 'managing the templates needs the permission' do
      Role.find(1).remove_permission!(:manage_issue_templates)
      post :create, params: { project_id: 'ecookbook', issue_template_file: { path: 'a.md', content: 'x' } }
      assert_response :forbidden
    end
  end
end
