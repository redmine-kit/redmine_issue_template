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
      # the chooser the files make (config.yml's preview)
      assert_equal ['bug_report'], data.dig('chooser', 'templates').pluck('key')
      assert_equal false, data.dig('chooser', 'blank')
    end

    test "a file's preview: a template's row and its part of the form, as the new issue's form gets them" do
      get :show, params: { project_id: 'ecookbook', id: file.id, format: 'json' }
      preview = response.parsed_body.dig('issue_template_file', 'preview')
      assert_equal 'template', preview['kind']
      assert_equal 'bug_report', preview.dig('chooser_row', 'key')
      assert_nil preview.dig('issue', 'description'), "a form's description is made from the answers"
      refs = preview.dig('section', 'elements').filter_map { |element| element['ref'] }
      assert_includes refs, 'what-happened'
      assert_includes refs, 'screenshots'

      get :show, params: { project_id: 'ecookbook', id: file('config.yml').id, format: 'json' }
      preview = response.parsed_body.dig('issue_template_file', 'preview')
      assert_equal 'config', preview['kind']
      assert_equal ['bug_report'], preview.dig('chooser', 'templates').pluck('key')
    end

    test 'a file with errors has no preview, and its messages' do
      broken = IssueTemplateFile.new(project: @project, path: 'broken.yml', content: "name: Broken\nbody: []\n")
      broken.save!(validate: false)
      get :show, params: { project_id: 'ecookbook', id: broken.id, format: 'json' }
      data = response.parsed_body['issue_template_file']
      assert_nil data['preview']
      assert(data['messages'].any? { |message| message['level'] == 'error' })
    end

    test 'the preview of a file as typed: nothing is saved' do
      task = "---\nname: Task\nabout: A task\ntitle: \"[Task] \"\n---\n## Steps\n"
      assert_no_difference 'IssueTemplateFile.count' do
        post :preview, params: { project_id: 'ecookbook', format: 'json',
                                 issue_template_file: { path: 'task.md', content: task } }
      end
      assert_response :success
      preview = response.parsed_body.dig('preview', 'preview')
      assert_equal({ 'subject' => '[Task] ', 'description' => "## Steps\n" },
                   preview['issue'].slice('subject', 'description').transform_values { |v| v.gsub("\r\n", "\n") })
      assert_equal 'Task', preview.dig('chooser_row', 'name')

      # an existing file with what was typed in place of its saved text
      post :preview, params: { project_id: 'ecookbook', format: 'json',
                               issue_template_file: { id: file.id.to_s, path: 'bug_report.yml', content: "name: x\n" } }
      assert_nil response.parsed_body.dig('preview', 'preview')
      assert(response.parsed_body.dig('preview', 'messages').any? { |message| message['level'] == 'error' })
      assert_includes file.reload.content, 'Bug Report'
    end

    # name => the file's params; each gets its messages (no preview), never an error of the server
    {
      'a name with a folder' => { path: '../x.md', content: "---\nname: x\nabout: y\n---\n" },
      'a name of another kind' => { path: 'x.txt', content: 'x' },
      'YAML with an alias' => { path: 'x.yml', content: "a: &a [1]\nb: *a\n" },
      'a text too long' => { path: 'x.md', content: 'x' * (Parser::MAX_LENGTH + 1) }
    }.each do |name, given|
      test "the preview of a file as typed: #{name}" do
        post :preview, params: { project_id: 'ecookbook', format: 'json', issue_template_file: given }
        assert_response :success
        assert_nil response.parsed_body.dig('preview', 'preview')
        assert(response.parsed_body.dig('preview', 'messages').any? { |message| message['level'] == 'error' })
      end
    end

    # name => params of the preview; each is 404 or a preview of a new file, never an error of the server
    {
      "another project's file" => lambda {
        other = IssueTemplateFile.create!(project_id: 2, path: 'o.md', content: '')
        { issue_template_file: { id: other.id.to_s, path: 'o.md' } }
      },
      'an id that is a list' => -> { { issue_template_file: { id: ['1'], path: 'a.md' } } },
      'a file that is a string' => -> { { issue_template_file: 'x' } }
    }.each do |name, given|
      test "the preview's unexpected params: #{name}" do
        post :preview, params: { project_id: 'ecookbook', format: 'json' }.merge(instance_exec(&given))
        assert_includes [200, 404], response.status
        if response.status == 200
          assert_not_equal 'o', response.parsed_body.dig('preview', 'preview', 'chooser_row', 'key'),
                           "another project's file is never read"
        end
      end
    end

    test 'the preview of templates from the repository: 403, as their forms' do
      import({ 'bug_report.yml' => github_fixture('bug_report.yml') }, @project, source: 'repository')
      post :preview, params: { project_id: 'ecookbook', format: 'json', issue_template_file: { path: 'a.md' } }
      assert_response :forbidden
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
        post :preview, params: { project_id: 'ecookbook', format: 'json', issue_template_file: { path: 'a.md' } }
        assert_includes [401, 403], response.status
        get :show, params: { project_id: 'ecookbook', id: file.id, format: 'json' }
        assert_includes [401, 403], response.status
      end
    end

    test 'the module turned off: refused' do
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      get :files, params: { project_id: 'ecookbook', format: 'json' }
      assert_response :forbidden
      post :preview, params: { project_id: 'ecookbook', format: 'json', issue_template_file: { path: 'a.md' } }
      assert_response :forbidden
    end

    test "the tab's data as a page is Redmine's settings tab" do
      @request.session[:user_id] = 2
      get :files, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/settings/issue_templates'
    end
  end
end
