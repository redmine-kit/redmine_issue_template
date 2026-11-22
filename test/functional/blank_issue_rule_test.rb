# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # The blank issue rule (IssuePatch#issue_template_missing?) on Redmine's
    # issues#create: the classic form and the new UI's requests follow it (the
    # chooser again, or 422 with the message), the REST API is left to Redmine.
    # The developer (dlopper, role 2) adds issues and doesn't manage templates.
    class BlankIssueRuleTest < Redmine::ControllerTest
      include RedmineKit::IssueTemplate::TestHelper

      tests IssuesController
      fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :trackers, :projects_trackers,
               :enabled_modules, :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects,
               :custom_fields_trackers, :custom_values, :issue_categories, :versions, :workflows, :issues

      IDEA = <<~MARKDOWN
        ---
        name: Idea
        about: An idea
        title: "[Idea] "
        type: Bug
        ---
        The idea
      MARKDOWN

      def setup
        @project = enable_issue_templates
        Role.find(2).add_permission!(:add_issues)
      end

      def blank_issues(enabled)
        import('idea.md' => IDEA, 'config.yml' => "blank_issues_enabled: #{enabled}\n")
      end

      def create(path, template)
        params = { project_id: 'ecookbook', issue: { tracker_id: '1', subject: 'Made' } }
        params[:issue_template] = 'idea' if template
        case path
        when :classic
          @request.session[:user_id] = 3
        when :kit
          IssuesController.any_instance.stubs(:find_current_user).returns(User.find(3))
          IssuesController.any_instance.stubs(:issue_template_kit_request?).returns(true)
          @request.headers['X-Redmine-Kit'] = '1'
          params[:format] = 'json'
        when :rest
          @request.env['HTTP_X_REDMINE_API_KEY'] = User.find(3).api_key
          params[:format] = 'json'
        end
        with_settings(rest_api_enabled: '1') { post :create, params: params }
      end

      # path, blank issues enabled, with the template => saved
      [
        [:classic, false, false, false], [:classic, false, true, true],
        [:classic, true, false, true], [:classic, true, true, true],
        [:kit, false, false, false], [:kit, false, true, true],
        [:kit, true, false, true], [:kit, true, true, true],
        [:rest, false, false, true], [:rest, false, true, true],
        [:rest, true, false, true], [:rest, true, true, true]
      ].each do |path, enabled, template, saved|
        test "#{path}, blank issues #{enabled ? 'on' : 'off'}, #{template ? 'with' : 'without'} a template" do
          blank_issues(enabled)
          count = Issue.count
          create(path, template)
          assert_equal count + (saved ? 1 : 0), Issue.count, response.body
          if saved
            assert_equal 'Made', Issue.order(:id).last.subject
          elsif path == :classic
            assert_redirected_to '/projects/ecookbook/issues/templates'
            assert_equal 'Choose a template to create an issue.', flash[:error]
          else
            assert_response :unprocessable_content
            assert_equal ['Choose a template to create an issue.'], response.parsed_body['errors']
          end
        end
      end

      test 'a copy in the browser is not refused: it is made from its issue' do
        blank_issues(false)
        @request.session[:user_id] = 3
        Role.find(2).add_permission!(:copy_issues)
        assert_difference('Issue.count', 1) do
          post :create, params: { project_id: 'ecookbook', copy_from: '1',
                                  issue: { tracker_id: '1', subject: 'Copied', status_id: '1', priority_id: '4' } }
        end
      end
    end
  end
end
