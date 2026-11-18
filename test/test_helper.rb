# frozen_string_literal: true

# Coverage of the plugin's own files (init.rb, app/, lib/) by its tests, when
# bin/test asks for it (COVERAGE=1 bin/test sets PLUGIN_COVERAGE), written as
# Cobertura XML to coverage/coverage.xml for Codecov. It starts before Redmine
# loads, so that the files are counted from the start; files no test loads count
# as not covered. Started once: another plugin's test helper loaded later
# doesn't start it again.
if ENV['PLUGIN_COVERAGE'] && !(defined?(SimpleCov) && SimpleCov.running)
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.command_name ENV['PLUGIN_COVERAGE']
  SimpleCov.start do
    root File.expand_path('..', __dir__)
    # A glob from the plugin's folder: SimpleCov reads it from the current one (Redmine's).
    track_files "#{root}/{init.rb,app/**/*.rb,lib/**/*.rb}"
    add_filter { |file| !file.project_filename.match?(%r{\A/(?:init\.rb\z|app/|lib/)}) }
    enable_coverage :branch
    merge_timeout 3600
    formatter SimpleCov::Formatter::CoberturaFormatter
  end
end

require File.expand_path('../../../test/test_helper', __dir__)
require 'open3'

module RedmineKit
  module IssueTemplate
    module TestHelper
      FIXTURES = File.expand_path('fixtures', __dir__)

      def github_fixture(name)
        File.read(File.join(FIXTURES, 'github', name))
      end

      # The example templates (test/fixtures/github/README.md), as a template folder.
      def github_files
        %w[bug_report.yml bug.md config.yml].to_h { |name| [name, github_fixture(name)] }
      end

      # Project 1 (eCookbook) with the module on, and Manager (role 1, jsmith)
      # allowed to manage the templates.
      def enable_issue_templates(project = Project.find(1))
        project.enabled_module_names = project.enabled_module_names | ['issue_templates']
        Role.find(1).add_permission!(:manage_issue_templates)
        project
      end

      # import({ 'bug.md' => '...' }) or import('bug.md' => '...'): Ruby passes a
      # braceless hash with string keys as keywords.
      def import(files = nil, project = Project.find(1), source: 'manual', folder: nil, **named)
        files ||= named.transform_keys(&:to_s)
        RedmineKit::IssueTemplate::Importer.import(project, files: files, source: source, folder: folder)
      end

      # A git repository with the given files committed, for Redmine's Git
      # repository of the project. Returns [repository, work tree].
      def git_repository(project, files)
        dir = Dir.mktmpdir('issue-template-repo')
        git(dir, 'init', '-q', '-b', 'main')
        commit_files(dir, files)
        repository = Repository::Git.create!(project: project, url: File.join(dir, '.git'), identifier: 'templates',
                                             is_default: true)
        @git_dirs = (@git_dirs || []) << dir
        [repository, dir]
      end

      def commit_files(dir, files, message = 'Update templates')
        files.each do |path, content|
          full = File.join(dir, path)
          if content.nil?
            FileUtils.rm_f(full)
          else
            FileUtils.mkdir_p(File.dirname(full))
            File.write(full, content)
          end
        end
        git(dir, 'add', '-A')
        git(dir, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '--allow-empty', '-m',
            message)
      end

      def git(dir, *args)
        _, error, status = Open3.capture3('git', '-C', dir, *args)
        raise "git #{args.join(' ')}: #{error}" unless status.success?
      end

      def remove_git_dirs
        Array(@git_dirs).each { |dir| FileUtils.rm_rf(dir) }
      end
    end
  end
end
