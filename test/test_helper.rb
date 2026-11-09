# frozen_string_literal: true

# Coverage of the plugin's own files (bin/test sets PLUGIN_COVERAGE for the
# plugin's tests), written as Cobertura XML to coverage/ for Codecov. It starts
# before Redmine loads, so that lib/ and app/ are counted.
if ENV['PLUGIN_COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'
  SimpleCov.start do
    root File.expand_path('..', __dir__)
    add_filter '/test/'
    enable_coverage :branch
    formatter SimpleCov::Formatter::CoberturaFormatter
  end
end

require File.expand_path('../../../test/test_helper', __dir__)
require 'open3'

module RedmineIssueTemplate
  module TestHelper
    FIXTURES = File.expand_path('fixtures', __dir__)

    def github_fixture(name)
      File.read(File.join(FIXTURES, 'github', name))
    end

    # The examples of GitHub's documentation, as a template folder.
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
    def import(files = nil, project = Project.find(1), source: 'manual', **named)
      files ||= named.transform_keys(&:to_s)
      RedmineIssueTemplate::Importer.import(project, files: files, source: source)
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
