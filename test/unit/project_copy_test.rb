# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # A project's templates in Redmine's project copy: the copy page's item チケットテンプレート (with the number of
    # files) and, when it is chosen, the files and their sharing, edited in the copy's settings.
    class ProjectCopyTest < ActiveSupport::TestCase
      include RedmineKit::IssueTemplate::TestHelper

      fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
               :issue_statuses, :enumerations

      def setup
        @source = enable_issue_templates(Project.generate!)
        import({ 'bug.md' => "---\nname: Bug\nabout: a\n---\n", 'config.yml' => "blank_issues_enabled: false\n" },
               @source, source: 'repository', folder: '.redmine/ISSUE_TEMPLATE')
        TemplateSource.find_by!(project_id: @source.id).update!(sharing: 'descendants')
      end

      def copy(only)
        project = Project.new(name: 'Copy', identifier: "copy-#{SecureRandom.hex(4)}")
        assert project.copy(@source, only.nil? ? {} : { only: })
        project
      end

      # the copy page's list => copied
      { nil => true, ['', 'issue_templates'] => true, ['', 'members'] => false, [''] => false }.each do |only, copied|
        test "the templates with the list #{only.inspect}" do
          project = copy(only)
          files = TemplateFile.where(project_id: project.id).pluck(:path).sort
          assert_equal copied ? %w[bug.md config.yml] : [], files
          source = TemplateSource.find_by(project_id: project.id)
          if copied
            assert_equal %w[manual descendants], [source&.kind, source&.sharing]
          else
            assert_nil source
          end
        end
      end

      test 'the copy uses its own templates' do
        project = copy(nil)
        assert_equal ['Bug'], TemplateSet.for(project).usable.map(&:name)
        assert_equal project, TemplateSource.provider_for(project)
      end

      test "the copy page's item, as Redmine's" do
        view = ActionView::Base.empty
        html = Hooks.instance.view_projects_copy_only_items(project: @source, hook_caller: view)
        assert_includes html, 'value="issue_templates"'
        assert_includes html, 'Issue templates (2)'
      end
    end
  end
end
