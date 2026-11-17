# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  # Project settings › Issue templates for the new UI: the settings actions
  # answering JSON (the new UI's requests, with the browser's session; the
  # session's user is given to the controller, as redmine_kit_ui would find
  # it), each with the same checks as Redmine's page.
  class KitSettingsTest < Redmine::ControllerTest
    include RedmineIssueTemplate::TestHelper

    tests IssueTemplatesController
    fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
             :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
             :custom_fields_trackers, :issue_categories, :versions, :workflows

    def setup
      @project = enable_issue_templates
      import('bug_report.yml' => github_fixture('bug_report.yml'), 'config.yml' => github_fixture('config.yml'))
      as_user(User.find(2))
    end

    def teardown
      remove_git_dirs
    end

    def as_user(user)
      IssueTemplatesController.any_instance.stubs(:find_current_user).returns(user)
    end

    def file(path = 'bug_report.yml')
      IssueTemplateFile.find_by!(project_id: @project.id, path: path)
    end

    def config
      TemplateSet.for(@project).config
    end

    test "the tab's data: where the files come from, the files with their state, the chooser's settings" do
      get :files, params: { project_id: 'ecookbook', format: 'json' }
      assert_response :success
      data = response.parsed_body['issue_templates']
      assert data['manual']
      assert_nil data['source']
      assert_equal %w[bug_report.yml config.yml], data['files'].pluck('path')
      assert_equal({ 'kind' => 'form', 'name' => 'Bug Report', 'errors' => 0 },
                   data['files'].first.slice('kind', 'name', 'errors'))
      assert_equal false, data['config']['blank_issues_enabled']
      assert_equal 2, data['config']['contact_links'].size
    end

    test "a file: its content and messages; another project's file is 404" do
      get :show, params: { project_id: 'ecookbook', id: file.id, format: 'json' }
      assert_response :success
      assert_equal file.content, response.parsed_body.dig('issue_template_file', 'content')

      other = IssueTemplateFile.create!(project_id: 2, path: 'other.md', content: "---\nname: x\nabout: y\n---\n")
      get :show, params: { project_id: 'ecookbook', id: other.id, format: 'json' }
      assert_response :not_found
    end

    test 'a file is created, updated and deleted; a bad one gets the messages' do
      task = "---\nname: Task\nabout: A task\n---\n"
      post :create, params: { project_id: 'ecookbook', format: 'json',
                              issue_template_file: { path: 'task.md', content: task } }
      assert_response :created
      created = file('task.md')
      assert_equal created.id, response.parsed_body.dig('issue_template_file', 'id')

      chore = "---\nname: Chore\nabout: A chore\n---\n"
      put :update, params: { project_id: 'ecookbook', id: created.id, format: 'json',
                             issue_template_file: { path: 'task.md', content: chore } }
      assert_response :no_content
      assert_includes created.reload.content, 'Chore'

      post :create, params: { project_id: 'ecookbook', format: 'json', issue_template_file: { path: '../x.md' } }
      assert_response :unprocessable_content
      assert response.parsed_body['errors'].any?

      delete :destroy, params: { project_id: 'ecookbook', id: created.id, format: 'json' }
      assert_response :no_content
      assert_nil IssueTemplateFile.find_by(id: created.id)
    end

    test "the chooser's settings are saved into config.yml (PUT: the new UI's requests have no PATCH)" do
      put :settings, params: { project_id: 'ecookbook', format: 'json', blank_issues_enabled: true,
                               contact_links: [{ name: 'Help', url: 'https://example.net/help', about: 'Ask' },
                                               { name: '', url: '', about: '' }] }
      assert_response :no_content
      assert config.blank_issues_enabled?
      links = config.contact_links.map { |link| [link.name, link.url, link.about] }
      assert_equal [%w[Help https://example.net/help Ask]], links
    end

    # name => params of an unexpected shape; each is ignored or refused, never an error of the server
    {
      'contact links that are a string' => { contact_links: 'x' },
      'a contact link that is a list' => { contact_links: [%w[a b]] },
      'a file that is a string' => { issue_template_file: 'x' }
    }.each do |name, params|
      test "unexpected shapes: #{name}" do
        action = params.key?(:issue_template_file) ? :create : :settings
        process action, method: action == :create ? 'POST' : 'PUT',
                        params: { project_id: 'ecookbook', format: 'json' }.merge(params)
        assert_includes [204, 422], response.status
      end
    end

    test 'templates from the repository are edited there: 403 with the message' do
      import({ 'bug_report.yml' => github_fixture('bug_report.yml') }, @project, source: 'repository')
      post :create, params: { project_id: 'ecookbook', format: 'json', issue_template_file: { path: 'a.md' } }
      assert_response :forbidden
      assert_equal [I18n.t(:error_issue_template_managed_elsewhere)], response.parsed_body['errors']
    end

    test 'the import without a repository: 422 with the message' do
      Repository.where(project_id: @project.id).delete_all
      post :sync, params: { project_id: 'ecookbook', format: 'json' }
      assert_response :unprocessable_content
      assert_equal [I18n.t(:error_issue_template_no_repository)], response.parsed_body['errors']
    end

    # who => the status of each action
    {
      'a member without the permission' => -> { User.find(3) },
      'a non-member' => -> { User.find(8) },
      'the anonymous user' => -> { User.anonymous }
    }.each do |name, who|
      test "#{name}: refused" do
        as_user(instance_exec(&who))
        get :files, params: { project_id: 'ecookbook', format: 'json' }
        assert_includes [401, 403], response.status
        put :settings, params: { project_id: 'ecookbook', format: 'json', blank_issues_enabled: true }
        assert_includes [401, 403], response.status
        assert_not config.blank_issues_enabled?
      end
    end

    test 'the module turned off: refused' do
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      get :files, params: { project_id: 'ecookbook', format: 'json' }
      assert_response :forbidden
    end

    test "the tab's data as a page is Redmine's settings tab" do
      @request.session[:user_id] = 2
      get :files, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
    end
  end
end
