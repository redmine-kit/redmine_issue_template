# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # The new UI's New issue (redmine_kit_ui's docs/plugins-kit.md, "The new
    # issue's form"): KitForm's answer to the hook kit_ui_new_issue_form, and
    # Redmine's issues#new and #create for the new UI's requests (JSON with the
    # header X-Redmine-Kit, the browser's session; redmine_kit_ui is not
    # installed here, so the session's user is given to the controller).
    class KitIssueFormTest < Redmine::ControllerTest
      include RedmineKit::IssueTemplate::TestHelper

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

      # A kit request: redmine_kit_ui's rule (RedmineKitUi.kit_request?, the
      # session's JSON with X-Redmine-Kit) answers yes.
      def as_kit_user(user)
        IssuesController.any_instance.stubs(:find_current_user).returns(user)
        IssuesController.any_instance.stubs(:issue_template_kit_request?).returns(true)
        @request.headers['X-Redmine-Kit'] = '1'
      end

      test 'without a template: the chooser as the step, with the templates the user may use' do
        part = answer(new_issue)
        assert_equal 'redmine_kit_issue_template', part[:plugin]
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
        TemplateFile.where(project_id: @project.id).delete_all
        assert_nil answer(new_issue)
      end

      test "a Markdown template: its part with the values it sets, and the issue's subject and description" do
        issue = built({ issue_template: 'feature' })
        part = answer(issue)
        assert_not part[:step]
        assert_equal 'Feature request', part[:data][:template][:name]
        assert_equal [{ label: 'Priority', value: 'High' }, { label: 'Category', value: 'Recipes' }],
                     part[:data][:preset]
        assert_equal [], part[:data][:elements]
        assert_equal '[Feature] ', issue.subject
        assert_equal "## The idea\n", issue.description.gsub("\r\n", "\n")
        # the values it sets aren't the user's to set
        assert_not_includes issue.safe_attribute_names(User.find(2)), 'priority_id'
      end

      test "a template's part asks the app to show the values it sets at their places, read-only" do
        part = answer(built({ issue_template: 'feature' }))
        assert_equal 'Read-only (set by the template)', part[:locked][:reason]
        assert_equal [{ field: 'priority_id', label: 'Priority', value: 'High' },
                      { field: 'category_id', label: 'Category', value: 'Recipes' }], part[:locked][:fields]
        assert_not part[:fold_attributes], "a Markdown template's form is Redmine's, unfolded"
        assert(part[:locked][:fields].all? { |field| issue_not_settable?(field[:field]) })
      end

      test "a form's part folds the form's other fields" do
        assert answer(built({ issue_template: 'bug_report' }))[:fold_attributes]
      end

      test "the sidebar: where the templates come from, the template's file, the settings tab for its managers" do
        part = answer(built({ issue_template: 'feature' }))
        sidebar = part[:data][:sidebar]
        assert_equal 'feature.md', sidebar[:path]
        assert_equal '/projects/ecookbook/settings/issue_templates', sidebar[:settings_path]
        # a user who may only add issues: no settings link; the chooser has the sidebar too
        user = User.find(3)
        assert_nil answer(new_issue(user), {}, user: user)[:data][:sidebar][:settings_path]
      end

      test "the sidebar lists the fields the template hides, by Redmine's labels" do
        import('hidden.md' => <<~MARKDOWN)
          ---
          name: Hidden
          about: Hides fields
          fields:
            due_date: hidden
            estimated_hours: hidden
          ---
          Text
        MARKDOWN
        sidebar = answer(built({ issue_template: 'hidden' }))[:data][:sidebar]
        assert_equal ['Due date', 'Estimated time'], sidebar[:hidden]
      end

      test "a field with a link names the issue's field it sets" do
        import('regression.yml' => <<~YAML)
          name: Regression
          description: Report something that broke in a version.
          body:
            - id: version
              link: fixed_version
              attributes:
                label: Broken in version
            - type: textarea
              id: what
              attributes:
                label: What broke?
        YAML
        elements = answer(built({ issue_template: 'regression' }))[:data][:elements]
        assert_equal 'Target version', elements.detect { |element| element[:type] == 'link' }[:field]
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

      # "New issue" outside a project (the app's step that picks the project, Redmine's /issues/new): the project is
      # issue[project_id], as Redmine's build_new_issue_from_params reads it, and its templates apply.
      { 'an id' => '1', 'an identifier' => 'ecookbook' }.each do |name, project_id|
        test "a template outside a project's URL, the project given as #{name}: its part, in that project" do
          @request.session[:user_id] = 2
          get :new, params: { issue_template: 'feature', issue: { project_id: project_id } }
          issue = @controller.instance_variable_get(:@issue)
          assert_equal @project, issue.project
          assert issue.issue_template_active?, 'the chosen template applies'
          part = answer(issue)
          assert_not part[:step], 'the form, not the chooser again'
          assert_equal 'Feature request', part[:data][:template][:name]
          assert_equal '[Feature] ', issue.subject
        end
      end

      test "the new UI's create outside a project's URL with a template: in the template's project, with the answers" do
        as_kit_user(User.find(3))
        assert_difference 'Issue.count' do
          post :create, params: { format: 'json', issue_template: 'bug_report',
                                  issue: { project_id: '1', subject: 'Crash' },
                                  issue_template_answers: { 'what-happened' => 'It crashed', 'version' => '0',
                                                            'terms' => ['0'] } }
        end
        assert_response :created
        issue = Issue.last
        assert_equal @project, issue.project
        assert_includes issue.description.gsub("\r\n", "\n"), "### What happened?\n\nIt crashed"
      end

      test "outside a project's URL, a project the user may not add issues to: none of its templates applies" do
        other = enable_issue_templates(Project.find(2))
        import({ 'store.md' => FEATURE }, other)
        @request.session[:user_id] = 3 # not a member of onlinestore (private)
        get :new, params: { issue_template: 'store', issue: { project_id: '2' } }
        issue = @controller.instance_variable_get(:@issue)
        assert_equal @project, issue.project, "Redmine's choice: the first project the user may add issues to"
        assert_nil issue.issue_template, "the other project's template"
        assert_equal '[Feature] ', TemplateSet.for(other).templates.first.title, 'the template is there'
      end

      test "the new UI's create with a template that no longer applies: 422" do
        as_kit_user(User.find(3))
        post :create, params: { project_id: 'ecookbook', format: 'json', issue_template: 'gone',
                                issue: { subject: 'Old', tracker_id: 1 } }
        assert_response :unprocessable_content
        assert_equal [I18n.t(:error_issue_template_unavailable)], response.parsed_body['errors']
      end

      test 'the REST API with the header but no session is left to Redmine too (redmine_kit_ui decides)' do
        with_settings rest_api_enabled: '1' do
          @request.headers['X-Redmine-API-Key'] = User.find(3).api_key
          @request.headers['X-Redmine-Kit'] = '1'
          post :create, params: { project_id: 'ecookbook', format: 'json', issue: { subject: 'API', tracker_id: 1 } }
        end
        assert_response :created
      end

      test "an upload field: the part's element with the extensions it takes" do
        accept = "\n      accept: \".png,.jpg\""
        form = github_fixture('bug_report.yml').sub(/(type: upload.*?required: false)/m, "\\1#{accept}")
        import('bug_report.yml' => form)
        upload = answer(built({ issue_template: 'bug_report' }))[:data][:elements].detect { |e| e[:type] == 'upload' }
        assert_equal({ type: 'upload', ref: 'screenshots', accept: %w[.png .jpg] }, upload.slice(:type, :ref, :accept))
      end

      # The new UI's upload fields (NewIssueFileField): the app sends the files in
      # Redmine's own `uploads` and the part names them by attachment id. Each
      # case: the files the request gives Redmine, the ids the field names, and
      # whether the issue is created with the file in the field (a required one).
      UPLOAD_CASES = {
        "the user's own upload, sent and named" => [->(mine, _other, _attached) { [[mine], [mine.id.to_s]] }, true],
        'an id of an upload the request did not send' => [->(mine, _other, _attached) { [[], [mine.id.to_s]] }, false],
        "another user's upload, its token sent" => [->(_mine, other, _attached) { [[other], [other.id.to_s]] }, false],
        'a file of another issue (attached already)' => [lambda { |_mine, _other, attached|
          [[attached], [attached.id.to_s]]
        }, false],
        'an id that is not a number' => [->(mine, _other, _attached) { [[mine], ["#{mine.id} OR 1=1"]] }, false],
        'ids of another shape (a mapping)' => [lambda { |mine, _other, _attached|
          [[mine], { 'a' => mine.id.to_s }]
        }, false],
        'no ids' => [->(mine, _other, _attached) { [[mine], nil] }, false]
      }.freeze

      UPLOAD_CASES.each do |name, (given, created)|
        test "the new UI's required upload field: #{name}" do
          set_tmp_attachments_directory
          form = github_fixture('bug_report.yml').sub(/(type: upload.*?required:) false/m, '\\1 true')
          import('bug_report.yml' => form)
          mine = upload('screen.png', 3)
          other = upload('theirs.png', 2)
          attached = upload('old.png', 3)
          attached.update!(container: Issue.find(1))
          sent, ids = given.call(mine, other, attached)
          as_kit_user(User.find(3))
          assert_difference 'Issue.count', created ? 1 : 0 do
            post :create, params: {
              project_id: 'ecookbook', format: 'json', issue_template: 'bug_report',
              issue: { subject: 'Upload', uploads: sent.map { |file| { token: file.token, filename: file.filename } } },
              issue_template_answers: { 'what-happened' => 'x', 'version' => '0', 'terms' => ['0'] },
              issue_template_uploads: ids ? { 'screenshots' => ids } : nil
            }.compact
          end
          if created
            issue = Issue.last
            assert_equal ['screen.png'], issue.attachments.map(&:filename)
            assert issue.description.gsub("\r\n", "\n").end_with?("### Upload screenshots\n\nattachment:\"screen.png\"")
          else
            assert_response :unprocessable_content
            assert(response.parsed_body['errors'].any? { |message| message.start_with?('Upload screenshots') })
            assert_nil other.reload.container, "another user's file is never attached"
          end
        end
      end

      test "the new UI's upload field without the permission to add issues: Redmine's 403, no file attached" do
        set_tmp_attachments_directory
        Role.find(2).remove_permission!(:add_issues)
        mine = upload('screen.png', 3)
        as_kit_user(User.find(3))
        assert_no_difference 'Issue.count' do
          post :create, params: { project_id: 'ecookbook', format: 'json', issue_template: 'bug_report',
                                  issue: { subject: 'No', uploads: [{ token: mine.token, filename: 'screen.png' }] },
                                  issue_template_uploads: { 'screenshots' => [mine.id.to_s] } }
        end
        assert_response :forbidden
        assert_nil mine.reload.container
      end

      test "the new UI's upload field takes only the extensions of accept" do
        set_tmp_attachments_directory
        accept = "\n      accept: \".png\""
        form = github_fixture('bug_report.yml').sub(/(type: upload.*?required: false)/m, "\\1#{accept}")
        import('bug_report.yml' => form)
        notes = upload('notes.txt', 3)
        as_kit_user(User.find(3))
        assert_no_difference 'Issue.count' do
          post :create, params: { project_id: 'ecookbook', format: 'json', issue_template: 'bug_report',
                                  issue: { subject: 'Accept',
                                           uploads: [{ token: notes.token, filename: 'notes.txt' }] },
                                  issue_template_answers: { 'what-happened' => 'x', 'version' => '0',
                                                            'terms' => ['0'] },
                                  issue_template_uploads: { 'screenshots' => [notes.id.to_s] } }
        end
        assert_includes response.parsed_body['errors'], 'Upload screenshots takes only these extensions: .png'
        assert_nil notes.reload.container
      end

      test 'the REST API without the header is left to Redmine: a blank issue is created' do
        with_settings rest_api_enabled: '1' do
          @request.headers['X-Redmine-API-Key'] = User.find(3).api_key
          post :create, params: { project_id: 'ecookbook', format: 'json', issue: { subject: 'API', tracker_id: 1 } }
        end
        assert_response :created
      end

      private

      def issue_not_settable?(attribute)
        !built({ issue_template: 'feature' }).safe_attribute_names(User.find(2)).include?(attribute)
      end

      def upload(name, user_id)
        Attachment.create!(file: uploaded_test_file('testfile.txt', 'text/plain'), filename: name, author_id: user_id)
      end
    end
  end
end
