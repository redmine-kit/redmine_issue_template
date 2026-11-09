# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class ImportTest < ActiveSupport::TestCase
    include RedmineIssueTemplate::TestHelper

    fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
             :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects, :custom_fields_trackers,
             :issue_categories, :versions

    def setup
      @project = enable_issue_templates
    end

    def teardown
      remove_git_dirs
    end

    test 'import stores the files and the warnings for the project' do
      source = import(github_files, @project, source: 'github')
      assert_equal %w[bug.md bug_report.yml config.yml], IssueTemplateFile.where(project: @project).pluck(:path).sort
      assert_equal 'github', source.kind
      keys = source.message_list.map(&:key)
      assert_includes keys, 'projects_ignored'
      assert_includes keys, 'labels_ignored'
      assert_includes keys, 'assignees_ignored'
    end

    test 'import replaces the files and drops what is not a template' do
      import('a.md' => "---\nname: Alpha\nabout: a\n---\n")
      import('b.md' => "---\nname: Beta\nabout: b\n---\n", 'README.txt' => 'x',
             'sub/c.md' => "---\nname: C\nabout: c\n---\n")
      assert_equal %w[b.md c.md], IssueTemplateFile.where(project: @project).pluck(:path).sort
    end

    test 'redmine options resolve against the project' do
      content = <<~MARKDOWN
        ---
        name: Feature
        about: Ask for a feature
        redmine:
          tracker: Feature request
          priority: High
          category: Recipes
          fixed_version: "2.0"
          custom_fields:
            Searchable field: value
          fields:
            assigned_to: hidden
            due_date: required
            Database: hidden
            Nope: hidden
          unknown: 1
        ---
        Text
      MARKDOWN
      source = import('feature.md' => content)
      template = RedmineIssueTemplate::TemplateSet.for(@project).find('feature')
      assert_equal 'Feature request', template.tracker(@project).name
      defaults = RedmineIssueTemplate::IssueTemplateDefaults.new(template, @project).attributes
      expected = { 'tracker_id' => '2', 'description' => "Text\n", 'priority_id' => '6', 'category_id' => '2',
                   'fixed_version_id' => '3', 'custom_field_values' => { '2' => 'value' } }
      assert_equal expected, defaults.except('subject')
      visibility = template.options.visibility(@project)
      assert_equal({ hidden: %w[assigned_to_id 1], required: %w[due_date] }, visibility)
      assert_equal %w[redmine_unknown_key unknown_field], source.message_list.map(&:key).sort
    end

    test 'the tracker comes from type, then labels' do
      by_type = "---\nname: By type\nabout: a\ntype: support request\n---\n"
      by_label = "---\nname: By label\nabout: a\nlabels: [question, bug]\n---\n"
      import('a.md' => by_type, 'b.md' => by_label)
      set = RedmineIssueTemplate::TemplateSet.for(@project)
      assert_equal 'Support request', set.find('a').tracker(@project).name
      assert_equal 'Bug', set.find('b').tracker(@project).name
    end

    test 'invalid redmine options are errors' do
      content = "---\nname: Bad\nabout: a\nredmine:\n  is_private: maybe\n  fields:\n    assigned_to: invisible\n---\n"
      source = import('bad.md' => content)
      assert_equal %w[redmine_invalid_value redmine_invalid_visibility], source.message_list.select(&:error?).map(&:key)
      assert_not RedmineIssueTemplate::TemplateSet.for(@project).any?
    end

    test 'a template set is read again when the files change' do
      import('a.md' => "---\nname: Alpha\nabout: a\n---\n")
      assert_equal %w[a], RedmineIssueTemplate::TemplateSet.for(@project).usable.map(&:key)
      IssueTemplateFile.create!(project: @project, path: 'b.md', content: "---\nname: Beta\nabout: b\n---\n")
      assert_equal %w[a b], RedmineIssueTemplate::TemplateSet.for(@project).usable.map(&:key)
    end

    test 'sync imports the folder of the repository when it changes' do
      repository, dir = git_repository(@project, '.github/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      source = RedmineIssueTemplate::RepositorySource.sync(@project)
      assert_equal 'repository', source.kind
      assert_equal '.github/ISSUE_TEMPLATE', source.folder
      assert_equal %w[bug.md], IssueTemplateFile.where(project: @project).pluck(:path)

      assert_nil RedmineIssueTemplate::RepositorySource.sync(@project), 'nothing changed'

      commit_files(dir, '.redmine/ISSUE_TEMPLATE/feature.yml' => github_fixture('bug_report.yml'))
      repository.fetch_changesets
      assert_equal '.redmine/ISSUE_TEMPLATE', IssueTemplateSource.find_by(project: @project).folder
      assert_equal %w[feature.yml], IssueTemplateFile.where(project: @project).pluck(:path)
      assert_equal 40, IssueTemplateSource.find_by(project: @project).revision.to_s.length
    end

    test 'templates removed from the repository go away; manual ones stay' do
      repository, dir = git_repository(@project, '.redmine/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      RedmineIssueTemplate::RepositorySource.sync(@project)
      commit_files(dir, '.redmine/ISSUE_TEMPLATE/bug.md' => nil, 'README' => 'x')
      repository.fetch_changesets
      assert_equal 'manual', IssueTemplateSource.find_by(project: @project).kind
      assert_empty IssueTemplateFile.where(project: @project)

      IssueTemplateFile.create!(project: @project, path: 'a.md', content: "---\nname: Alpha\nabout: a\n---\n")
      commit_files(dir, 'README' => 'y')
      repository.fetch_changesets
      assert_equal %w[a.md], IssueTemplateFile.where(project: @project).pluck(:path)
    end

    test 'templates from GitHub are not replaced by a fetch unless forced' do
      git_repository(@project, '.redmine/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      import({ 'gh.md' => "---\nname: From GitHub\nabout: a\n---\n" }, @project, source: 'github')
      assert_nil RedmineIssueTemplate::RepositorySource.sync(@project)
      assert_equal %w[gh.md], IssueTemplateFile.where(project: @project).pluck(:path)
      RedmineIssueTemplate::RepositorySource.sync(@project, force: true)
      assert_equal %w[bug.md], IssueTemplateFile.where(project: @project).pluck(:path)
    end

    test 'sync does nothing without the module' do
      @project.enabled_module_names = @project.enabled_module_names - ['issue_templates']
      git_repository(@project, '.redmine/ISSUE_TEMPLATE/bug.md' => github_fixture('bug.md'))
      assert_nil RedmineIssueTemplate::RepositorySource.sync(@project)
    end

    test 'an unknown source is refused' do
      assert_raises(ArgumentError) { import({}, @project, source: 'svn') }
    end

    test 'deleting the project deletes its templates' do
      project = Project.generate!
      import({ 'a.md' => "---\nname: Alpha\nabout: a\n---\n" }, project)
      project.reload.destroy
      assert_empty IssueTemplateFile.where(project_id: project.id)
      assert_nil IssueTemplateSource.find_by(project_id: project.id)
    end
  end
end
