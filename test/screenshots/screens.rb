# frozen_string_literal: true

require_relative 'screenshot_case'
require_relative '../test_helper'

# The screens of docs/README.md: GitHub's examples as the templates of the
# eCookbook project, plus a file with an error and a template with warnings
# for the settings tab.
class RedmineIssueTemplateScreenshotsTest < ScreenshotCase
  include RedmineIssueTemplate::TestHelper

  FEATURE = <<~MARKDOWN
    ---
    name: Feature request
    about: Suggest an idea for this project
    labels: [Feature request, enhancement]
    redmine:
      priority: Normal
      fields:
        estimated_hours: hidden
    ---
    ## The idea
  MARKDOWN

  def setup
    super
    Setting.text_formatting = 'common_mark'
    enable_issue_templates
  end

  def test_screens
    import(github_files.merge('feature.md' => FEATURE))
    each_language do |language|
      visit '/projects/ecookbook/issues/new'
      assert_selector 'table.list.issue-templates'
      shoot 'chooser', language

      visit '/projects/ecookbook/issues/new?issue_template=bug_report'
      assert_selector 'textarea[name="issue_template_answers[what-happened]"]'
      shoot 'issue-form', language, selector: '#issue-form'
    end

    import(github_files.merge('feature.md' => FEATURE, 'broken.yml' => "name: Broken form\nbody: []\n"))
    each_language do |language|
      visit '/projects/ecookbook/settings/issue_templates'
      assert_selector 'table.list.issue-template-files'
      shoot 'settings', language, selector: '#tab-content-issue_templates'
    end
  end
end
