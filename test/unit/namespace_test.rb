# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # RedmineKit is the namespace every plugin of Redmine Kit shares (the
    # organization's AGENTS.md, "One Ruby namespace: RedmineKit"): Zeitwerk
    # makes it from the plugins' lib/redmine_kit/ folders, and each plugin owns
    # only its own module under it. A plugin with a lib/redmine_kit.rb would
    # define the namespace itself, and Zeitwerk would ignore another plugin's
    # file of the same name without a word.
    class NamespaceTest < ActiveSupport::TestCase
      test 'the plugin defines no lib/redmine_kit.rb' do
        assert_not File.exist?(File.expand_path('../../lib/redmine_kit.rb', __dir__))
      end

      test 'the plugin is RedmineKit::IssueTemplate, under a module and not a class' do
        assert_equal 'RedmineKit::IssueTemplate', RedmineKit::IssueTemplate.name
        assert_instance_of Module, RedmineKit
      end

      test 'the controller, models and helpers are under RedmineKit::IssueTemplate' do
        root = File.expand_path('../../app', __dir__)
        files = Dir.glob('{controllers,models,helpers}/**/*.rb', base: root)
        assert_not_empty files
        files.each do |file|
          assert file.match?(%r{\A\w+/redmine_kit/issue_template/}), file
          constant = file.split('/', 2).last.delete_suffix('.rb').camelize.constantize
          assert constant.name.start_with?('RedmineKit::IssueTemplate::'), constant.name
        end
      end

      test 'the tables are prefixed with the plugin\'s name' do
        models = [TemplateFile, TemplateSource]
        assert_equal %w[redmine_kit_issue_template_files redmine_kit_issue_template_sources], models.map(&:table_name)
        assert(models.all?(&:table_exists?))
      end
    end
  end
end
