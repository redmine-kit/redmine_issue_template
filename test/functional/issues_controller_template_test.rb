# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class IssuesControllerTemplateTest < Redmine::ControllerTest
    include RedmineIssueTemplate::TestHelper

    tests IssuesController
    fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
             :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
             :custom_fields_trackers, :custom_values, :issue_categories, :versions, :workflows, :issues

    FEATURE = <<~MARKDOWN
      ---
      name: Feature request
      about: Suggest an idea
      title: "[Feature] "
      type: Feature request
      priority: High
      category: Recipes
      fields:
        estimated_hours: hidden
        due_date: required
        Custom date: hidden
      custom_fields:
        Custom date: "2026-12-24"
      ---
      ## The idea
    MARKDOWN

    def setup
      @project = enable_issue_templates
      @request.session[:user_id] = 2
      import('bug_report.yml' => github_fixture('bug_report.yml'), 'feature.md' => FEATURE,
             'config.yml' => github_fixture('config.yml'))
    end

    test 'New issue opens the template chooser' do
      get :new, params: { project_id: 'ecookbook' }
      assert_redirected_to '/projects/ecookbook/issues/templates'
    end

    test 'parameters of New issue go to the chooser' do
      get :new, params: { project_id: 'ecookbook', issue: { parent_issue_id: '1' } }
      assert_redirected_to '/projects/ecookbook/issues/templates?issue%5Bparent_issue_id%5D=1'
    end

    test 'without templates or without the module, New issue is Redmine\'s form' do
      IssueTemplateFile.delete_all
      RedmineIssueTemplate::TemplateSet.reset!
      get :new, params: { project_id: 'ecookbook' }
      assert_response :success

      import('feature.md' => FEATURE)
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      get :new, params: { project_id: 'ecookbook' }
      assert_response :success
    end

    test 'copying an issue skips the chooser' do
      get :new, params: { project_id: 'ecookbook', copy_from: 1 }
      assert_response :success
    end

    test 'a Markdown template fills in the form' do
      get :new, params: { project_id: 'ecookbook', issue_template: 'feature' }
      assert_response :success
      assert_select 'input[name=issue_template][value=feature]'
      # The values the template sets are text, not fields.
      assert_select 'select#issue_tracker_id', 0
      assert_select 'p', text: /Tracker\s+Feature request/
      assert_select 'input#issue_subject[value=?]', '[Feature] '
      assert_select 'textarea#issue_description', text: /\A## The idea/
      assert_select 'select#issue_priority_id', 0
      assert_select 'p', text: /Priority\s+High/
      assert_select 'select#issue_category_id', 0
      assert_select 'p', text: /Category\s+Recipes/
      assert_select 'input#issue_estimated_hours', 0
      assert_select 'label[for=issue_due_date] span.required'
      assert_select '#issue_custom_field_values_8', 0
    end

    test 'creating from a Markdown template keeps hidden values and checks required fields' do
      post :create, params: { project_id: 'ecookbook', issue_template: 'feature',
                              issue: { tracker_id: '2', subject: 'More recipes', description: 'Text', priority_id: '6',
                                       estimated_hours: '5' } }
      assert_response :success
      assert_select '#errorExplanation', text: /Due date/

      post :create, params: { project_id: 'ecookbook', issue_template: 'feature',
                              issue: { tracker_id: '2', subject: 'More recipes', description: 'Text', priority_id: '6',
                                       due_date: '2026-12-01', estimated_hours: '5' } }
      issue = Issue.order(:id).last
      assert_redirected_to "/issues/#{issue.id}"
      assert_nil issue.estimated_hours
      assert_equal '2026-12-24', issue.custom_field_value(8)
    end

    test 'an issue form shows its fields instead of the description' do
      get :new, params: { project_id: 'ecookbook', issue_template: 'bug_report' }
      assert_response :success
      assert_select '.issue-template-fields p', text: /Tracker\s+Bug/
      assert_select '#issue-form p', text: /Tracker/, count: 0
      # The subject and the fields are in a box above Redmine's form, and
      # belong to the form.
      assert_select '#issue-form input#issue_subject', 0
      assert_select '.issue-template-fields input#issue_subject[form=issue-form][value=?]', '[Bug]: '
      assert_select '.issue-template-fields textarea[form=issue-form][name=?]', 'issue_template_answers[what-happened]'
      assert_select 'head link[rel=stylesheet][href^=?]', '/assets/plugin_assets/redmine_issue_template/issue_template-'
      assert_select 'textarea#issue_description', 0
      assert_select 'input[name=?]', 'issue_template_answers[contact]'
      assert_select 'textarea[name=?]', 'issue_template_answers[what-happened]', text: 'A bug happened!'
      assert_select 'select[name=?] option[selected=selected]', 'issue_template_answers[version]',
                    text: '1.0.2 (Default)'
      assert_select 'select[name=?][multiple=multiple]', 'issue_template_answers[browsers][]'
      assert_select 'input[type=checkbox][name=?]', 'issue_template_answers[terms][]'
      # A required option is marked on the option, not on the field.
      assert_select 'p:has(input[name="issue_template_answers[terms][]"]) > label:not(.block) span.required', 0
      assert_select 'p:has(input[name="issue_template_answers[terms][]"]) label.block span.required'
      assert_select 'div.wiki', text: /Thanks for taking the time/
      # Markdown in descriptions is rendered.
      assert_select 'em.info a[href=?]', 'https://example.com', text: 'Code of Conduct'
    end

    test 'creating from an issue form writes the answers as the description' do
      post :create, params: {
        project_id: 'ecookbook', issue_template: 'bug_report',
        issue: { tracker_id: '1', subject: '[Bug]: Crash' },
        issue_template_answers: { 'what-happened' => 'It crashed', 'version' => '0', 'browsers' => ['', '1'],
                                  'terms' => ['', '0'] }
      }
      issue = Issue.order(:id).last
      assert_redirected_to "/issues/#{issue.id}"
      description = issue.description.gsub("\r\n", "\n")
      assert_includes description, "### What happened?\n\nIt crashed"
      assert_includes description, "### What browsers are you seeing the problem on?\n\nChrome"
      assert_includes description, "- [X] I agree to follow this project's Code of Conduct"
    end

    test 'an issue form checks its required fields' do
      post :create, params: { project_id: 'ecookbook', issue_template: 'bug_report',
                              issue: { tracker_id: '1', subject: 'Crash' },
                              issue_template_answers: { 'what-happened' => '', 'terms' => [''] } }
      assert_response :success
      assert_select '#errorExplanation li', text: /What happened\?/
      assert_select '#errorExplanation li', text: /Code of Conduct/
      assert_select 'textarea[name=?]', 'issue_template_answers[what-happened]', text: ''
    end

    test 'updating the form keeps the template' do
      post :new, params: { project_id: 'ecookbook', issue_template: 'bug_report',
                           form_update_triggered_by: 'issue_tracker_id', issue: { tracker_id: '3', subject: 'x' },
                           issue_template_answers: { 'contact' => 'me@example.com' } }, xhr: true
      assert_response :success
      # The form's fields are outside the part Redmine updates.
      assert_not_include 'issue_template_answers[contact]', response.body
      assert_not_include 'issue[subject]', response.body
    end

    test 'the project stays the one the template was chosen in' do
      # Without a template, Redmine offers the subprojects.
      get :new, params: { project_id: 'ecookbook', issue_template: 'blank' }
      assert_select 'select#issue_project_id'

      get :new, params: { project_id: 'ecookbook', issue_template: 'feature' }
      assert_response :success
      assert_select 'select#issue_project_id', 0

      post :new, params: { project_id: 'ecookbook', issue_template: 'feature',
                           form_update_triggered_by: 'issue_project_id',
                           issue: { project_id: '5', tracker_id: '2', subject: 'x' } }, xhr: true
      assert_response :success
      assert_not_include 'issue_project_id', response.body

      post :create, params: { project_id: 'ecookbook', issue_template: 'feature',
                              issue: { project_id: '5', tracker_id: '2', subject: 'More recipes', description: 'Text',
                                       priority_id: '6', due_date: '2026-12-01' } }
      issue = Issue.order(:id).last
      assert_redirected_to "/issues/#{issue.id}"
      assert_equal 1, issue.project_id
    end

    test 'a form without a tracker offers Redmine\'s trackers in its box' do
      question = <<~YAML
        name: Question
        description: Ask
        body:
          - type: input
            id: what
            attributes:
              label: What
      YAML
      import('question.yml' => question)
      get :new, params: { project_id: 'ecookbook', issue_template: 'question' }
      assert_response :success
      assert_select '.issue-template-fields select#issue_tracker_id[form=issue-form][onchange*=updateIssueFrom]'
      assert_select '#issue-form select#issue_tracker_id', 0

      post :create, params: { project_id: 'ecookbook', issue_template: 'question',
                              issue: { tracker_id: '3', subject: 'How?' }, issue_template_answers: { 'what' => 'x' } }
      assert_equal 3, Issue.order(:id).last.tracker_id
    end

    test 'the request cannot change the values the template sets' do
      post :create, params: { project_id: 'ecookbook', issue_template: 'feature',
                              issue: { tracker_id: '1', subject: 'More recipes', description: 'Text', priority_id: '4',
                                       category_id: '1', due_date: '2026-12-01' } }
      issue = Issue.order(:id).last
      assert_redirected_to "/issues/#{issue.id}"
      assert_equal [2, 6, 2], [issue.tracker_id, issue.priority_id, issue.category_id]
    end

    test 'blank issues: off in config.yml, still offered to those who manage the templates' do
      get :new, params: { project_id: 'ecookbook', issue_template: 'blank' }
      assert_response :success

      @request.session[:user_id] = 3
      Role.find(2).add_permission!(:add_issues)
      get :new, params: { project_id: 'ecookbook', issue_template: 'blank' }
      assert_redirected_to '/projects/ecookbook/issues/templates'
    end

    test 'an unknown template opens the chooser' do
      get :new, params: { project_id: 'ecookbook', issue_template: 'nope' }
      assert_redirected_to '/projects/ecookbook/issues/templates'
    end
  end
end
