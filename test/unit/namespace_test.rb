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
    end
  end
end
