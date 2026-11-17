# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  # The new UI's New issue (redmine_kit_ui's docs/plugins-kit.md, "The new
  # issue's form"): KitForm's answer to the hook kit_ui_new_issue_form, and
  # Redmine's issues#new and #create for the new UI's requests (JSON with the
  # header X-Redmine-Kit, the browser's session; redmine_kit_ui is not
  # installed here, so the session's user is given to the controller).
  class KitIssueFormTest < Redmine::ControllerTest
    include RedmineIssueTemplate::TestHelper

    tests IssuesController
    fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
             :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
             :custom_fields_trackers, :custom_values, :issue_categories, :versions, :workflows, :issues

    FEATURE = <<~MARKDOWN
      ---
      name: Feature request
      about: Suggest an *idea*
      title: "[Feature] "
      type: Feature request
      priority: High
      category: Recipes
      ---
      ## The idea
    MARKDOWN

    def setup
      @project = enable_issue_templates
      import('bug_report.yml' => github_fixture('bug_report.yml'), 'feature.md' => FEATURE,
             'config.yml' => github_fixture('config.yml'))
    end

    def answer(issue, params = {}, user: User.find(2))
      KitForm.answer(issue, ActionController::Parameters.new(params), user: user)
    end

    def new_issue(user = User.find(2))
      Issue.new(project: @project, author: user)
    end

    # The issue Redmine's issues#new builds for the request (with the
    # plugin's filters), as redmine_kit_ui's form reads it.
    def built(params, user_id: 2)
      @request.session[:user_id] = user_id
      get :new, params: { project_id: 'ecookbook' }.merge(params)
      @controller.instance_variable_get(:@issue)
    end

    def as_kit_user(user)
      IssuesController.any_instance.stubs(:find_current_user).returns(user)
      @request.headers['X-Redmine-Kit'] = '1'
    end

    test 'without a template: the chooser as the step, with the templates the user may use' do
      part = answer(new_issue)
      assert_equal 'redmine_issue_template', part[:plugin]
      assert_equal 'template', part[:name]
      assert part[:step]
      assert_equal %w[bug_report feature], part[:data][:templates].pluck(:key).sort
      feature = part[:data][:templates].detect { |row| row[:key] == 'feature' }
      assert_equal({ key: 'feature', name: 'Feature request', about: 'Suggest an *idea*', kind: 'markdown',
                     tracker: 'Feature request' }, feature)
      assert_equal 'GitHub Community Support', part[:data][:contact_links].first[:name]
    end

    # who => whether the chooser offers a blank issue (config.yml: blank_issues_enabled false)
    { 'a user who manages the templates' => [2, true], 'a user who may only add issues' => [3, false] }
      .each do |name, (user_id, blank)|
      test "the blank issue for #{name}: #{blank}" do
        user = User.find(user_id)
        assert_equal blank, answer(new_issue(user), {}, user: user)[:data][:blank]
        part = answer(new_issue(user), { issue_template: 'blank' }, user: user)
        assert_equal !blank, part[:step], 'a blank issue the user may not create is the chooser again'
      end
    end

    test 'nothing where the module is off or no template is usable: Redmine form alone' do
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      assert_nil answer(new_issue)

      @project.enabled_module_names = @project.enabled_module_names | ['issue_templates']
      IssueTemplateFile.where(project_id: @project.id).delete_all
      assert_nil answer(new_issue)
    end

    test "a Markdown template: its part with the values it sets, and the issue's subject and description" do
      issue = built({ issue_template: 'feature' })
      part = answer(issue)
      assert_not part[:step]
      assert_equal 'Feature request', part[:data][:template][:name]
      assert_equal [{ label: 'Priority', value: 'High' }, { label: 'Category', value: 'Recipes' }], part[:data][:preset]
      assert_equal [], part[:data][:elements]
      assert_equal '[Feature] ', issue.subject
      assert_equal "## The idea\n", issue.description.gsub("\r\n", "\n")
      # the values it sets aren't the user's to set
      assert_not_includes issue.safe_attribute_names(User.find(2)), 'priority_id'
    end

    test "a form: its fields with what the form starts with; the tracker and the subject are the app's fields" do
      issue = built({ issue_template: 'bug_report' })
      assert_not_includes issue.safe_attribute_names(User.find(2)), 'subject', "Redmine's form: in the form's part"
      elements = answer(issue)[:data][:elements]
      assert_equal 'markdown', elements.first[:type]
      what = elements.detect { |element| element[:ref] == 'what-happened' }
      assert_equal({ type: 'textarea', ref: 'what-happened', label: 'What happened?', required: true,
                     value: 'A bug happened!' }, what.slice(:type, :ref, :label, :required, :value))
      version = elements.detect { |element| element[:type] == 'dropdown' }
      assert_equal %w[0 1], version[:options].pluck(:value)
      names = issue.safe_attribute_names(User.find(2))
      assert_includes names, 'subject'
      assert_not_includes names, 'description', "a form's description is made from the answers"
    end

    test "the new UI's form request is not redirected to the chooser" do
      as_kit_user(User.find(2))
      begin
        get :new, params: { project_id: 'ecookbook', format: 'json' }
      rescue ActionController::UnknownFormat
        # Redmine's issues#new has no JSON of its own (redmine_kit_ui's form.json answers it):
        # the filters let it through
      end
      assert_not response.redirect?
    end

    test "the new UI's create with a template: the answers become the description" do
      as_kit_user(User.find(3))
      assert_difference 'Issue.count' do
        post :create, params: { project_id: 'ecookbook', format: 'json', issue_template: 'bug_report',
                                issue: { subject: 'Crash' },
                                issue_template_answers: { 'what-happened' => 'It crashed', 'version' => '0',
                                                          'terms' => ['0'] } }
      end
      assert_response :created
      issue = Issue.last
      assert_equal 'Crash', issue.subject
      assert_includes issue.description.gsub("\r\n", "\n"), "### What happened?\n\nIt crashed"
    end

    test "the new UI's create without a template, where blank issues are off: Redmine's 422" do
      as_kit_user(User.find(3))
      assert_no_difference 'Issue.count' do
        post :create, params: { project_id: 'ecookbook', format: 'json', issue: { subject: 'Blank', tracker_id: 1 } }
      end
      assert_response :unprocessable_content
      assert_equal [I18n.t(:error_issue_template_required)], response.parsed_body['errors']
    end

    test "the new UI's create with a template that no longer applies: 422" do
      as_kit_user(User.find(3))
      post :create, params: { project_id: 'ecookbook', format: 'json', issue_template: 'gone',
                              issue: { subject: 'Old', tracker_id: 1 } }
      assert_response :unprocessable_content
      assert_equal [I18n.t(:error_issue_template_unavailable)], response.parsed_body['errors']
    end

    test 'the REST API without the header is left to Redmine: a blank issue is created' do
      with_settings rest_api_enabled: '1' do
        @request.headers['X-Redmine-API-Key'] = User.find(3).api_key
        post :create, params: { project_id: 'ecookbook', format: 'json', issue: { subject: 'API', tracker_id: 1 } }
      end
      assert_response :created
    end
  end
end
