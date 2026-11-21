# frozen_string_literal: true

require_relative '../test_helper'

module RedmineKit
  module IssueTemplate
    # What Redmine's form and the new UI's form both show of a template:
    # LinkedFieldView and PresetValues.
    class PresentationTest < ActiveSupport::TestCase
      include RedmineKit::IssueTemplate::TestHelper

      fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :projects_trackers, :enabled_modules,
               :issue_statuses, :enumerations, :custom_fields, :custom_fields_projects, :custom_fields_trackers,
               :issue_categories, :versions, :workflows

      def element(link, options: nil)
        attributes = { 'label' => 'L' }
        attributes['options'] = options if options
        IssueForm::Element.new(index: 0, type: IssueForm::LINK, id: 'x', attributes: attributes, validations: {},
                               link: link)
      end

      def issue(links: [], preset: [])
        Issue.new(project: Project.find(1), tracker_id: 1, author_id: 2, status_id: 1, priority_id: 6,
                  category_id: 2).tap do |issue|
          issue.stubs(:issue_template_links).returns(links)
          issue.stubs(:issue_template_visibility).returns(hidden: [], required: [], preset: preset)
        end
      end

      test 'a link that applies is shown as the issue\'s field' do
        linked = element('priority')
        view = LinkedFieldView.new(issue(links: [LinkedField.new(linked, 'priority_id')]), linked)
        assert_equal :select, view.kind
        assert_not view.multiple?
        assert_equal IssuePriority.active.map(&:name), view.choices.map(&:first)
      end

      test 'a link that can\'t apply is a select of its own options' do
        view = LinkedFieldView.new(issue, element('nothing', options: %w[One Two]))
        assert_nil view.link
        assert_equal :select, view.kind
        assert_equal [%w[One One], %w[Two Two]], view.choices
      end

      test 'preset values: the fields the template sets, with Redmine\'s labels, but not those shown elsewhere' do
        values = PresetValues.new(issue(preset: %w[tracker_id priority_id category_id]), User.find(2),
                                  except: ['tracker_id'])
        shown = values.map { |entry| [entry.field, entry.label, entry.value.name] }
        assert_equal [%w[priority_id Priority High], %w[category_id Category Recipes]], shown
      end

      test 'preset values leave out custom fields the user can\'t see' do
        field = CustomField.find(2)
        field.update!(visible: false, role_ids: [1])
        target = issue(preset: [field.id.to_s])
        assert_equal [field.id.to_s], PresetValues.new(target, User.find(2)).map(&:field), 'a manager'
        assert_empty PresetValues.new(target, User.find(3)).to_a, 'a developer'
      end
    end
  end
end
