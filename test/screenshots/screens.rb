# frozen_string_literal: true

require_relative 'screenshot_case'
require_relative '../test_helper'

# The screens of the docs: the example templates as the templates of the
# eCookbook project, plus a file with an error for the settings tab and a
# form with links.
class RedmineIssueTemplateScreenshotsTest < ScreenshotCase
  include RedmineIssueTemplate::TestHelper

  FEATURE = <<~MARKDOWN
    ---
    name: Feature request
    about: Suggest an idea for this project
    type: Feature request
    labels: [enhancement]
    priority: Normal
    fields:
      estimated_hours: hidden
    ---
    ## The idea
  MARKDOWN

  # A form whose fields set the issue's target version and a custom field
  # (docs/format.md#links).
  LINKED = <<~YAML
    name: Regression
    description: Report something that broke in a version.
    type: Bug
    body:
      - id: version
        link: fixed_version
        attributes:
          label: Broken in version
        validations:
          required: true
      - id: database
        link: Database
        attributes:
          label: Database
      - type: textarea
        id: what
        attributes:
          label: What broke?
        validations:
          required: true
  YAML

  def setup
    super
    Setting.text_formatting = 'common_mark'
    enable_issue_templates
  end

  def test_screens
    shoot_chooser_and_form
    shoot_links
    shoot_settings
    shoot_preview
  end

  private

  def shoot_chooser_and_form
    import(github_files.merge('feature.md' => FEATURE))
    each_language do |language|
      visit '/projects/ecookbook/issues/new'
      assert_selector 'table.list.issue-templates'
      shoot 'chooser', language

      visit '/projects/ecookbook/issues/new?issue_template=bug_report'
      assert_selector 'textarea[name="issue_template_answers[what-happened]"]'
      # With the page's title, so that the form reads as Redmine's New issue.
      shoot 'issue-form', language
    end
  end

  # The settings tab with a form that has errors.
  def shoot_settings
    import(github_files.merge('feature.md' => FEATURE, 'broken.yml' => "name: Broken form\nbody: []\n"))
    each_language do |language|
      visit '/projects/ecookbook/settings/issue_templates'
      assert_selector 'table.list.issue-template-files'
      shoot 'settings', language, selector: '#tab-content-issue_templates'
    end
  end

  def shoot_preview
    file = IssueTemplateFile.find_by(path: 'feature.md')
    each_language do |language|
      visit "/projects/ecookbook/issue_templates/#{file.id}/edit"
      find('input[name=preview]').click
      assert_selector '.issue-template-preview'
      shoot 'preview', language, selector: '#content'
    end
  end

  # A form whose fields set the issue's fields, with values chosen, so that
  # the fields show the choices they take from Redmine.
  def shoot_links
    import(github_files.merge('feature.md' => FEATURE, 'regression.yml' => LINKED))
    each_language do |language|
      visit '/projects/ecookbook/issues/new?issue_template=regression'
      select '2.0', from: 'issue_template_answer_version', exact: true
      select 'PostgreSQL', from: 'issue_template_answer_database'
      shoot 'issue-form-link', language
    end
  end
end
