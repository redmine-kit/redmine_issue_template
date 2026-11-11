# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class LinkedFieldTest < ActiveSupport::TestCase
    include RedmineIssueTemplate::TestHelper

    fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
             :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects, :custom_fields_trackers,
             :issue_categories, :versions, :workflows

    def element(link, options: nil)
      attributes = { 'label' => 'L' }
      attributes['options'] = options if options
      IssueForm::Element.new(index: 0, type: IssueForm::LINK, id: 'x', attributes: attributes, validations: {},
                             link: link)
    end

    def issue
      Issue.new(project: Project.find(1), tracker_id: 1, author_id: 2, status_id: 1)
    end

    test 'links name the issue\'s fields or custom fields, but not files or derived % done' do
      project = Project.find(1)
      assert_equal 'fixed_version_id', LinkedField.resolve(project, 'fixed_version')
      assert_equal '1', LinkedField.resolve(project, 'Database')
      assert_equal '1', LinkedField.resolve(project, '1')
      assert_nil LinkedField.resolve(project, 'nothing')
      with_settings(issue_done_ratio: 'issue_status') do
        assert_nil LinkedField.resolve(project, 'done_ratio')
      end
    end

    test 'the field decides how it is shown' do
      { 'priority_id' => :select, 'due_date' => :date, 'estimated_hours' => :text, '1' => :select, '6' => :text,
        '8' => :date }.each do |attribute, kind|
        assert_equal kind, LinkedField.new(element('x'), attribute).kind(issue), attribute
      end
    end

    test 'options keep the choices of the same names or values, or all when none matches' do
      database = LinkedField.new(element('Database', options: %w[postgresql Oracle]), '1')
      assert_equal %w[PostgreSQL Oracle], database.choices(issue).map(&:first)
      unmatched = LinkedField.new(element('Database', options: %w[はい]), '1')
      assert_equal CustomField.find(1).possible_values, unmatched.choices(issue).map(&:first)
    end

    test 'only a current choice is applied' do
      target = issue
      LinkedField.new(element('priority'), 'priority_id').apply(target, '999999')
      assert_not_equal 999_999, target.priority_id
      LinkedField.new(element('priority'), 'priority_id').apply(target, IssuePriority.active.last.id.to_s)
      assert_equal IssuePriority.active.last.id, target.priority_id
    end
  end
end
