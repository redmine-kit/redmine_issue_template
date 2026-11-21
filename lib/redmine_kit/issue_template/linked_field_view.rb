# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # How a form's field with a link is shown, in Redmine's form
    # (templates/_linked_field) and in the new UI's (KitForm): as the
    # issue's field it sets (the LinkedField that applies), or, for a link that
    # can't apply, as a select of the element's own options, answered into
    # the description.
    class LinkedFieldView
      attr_reader :link, :kind

      def initialize(issue, element)
        @issue = issue
        @element = element
        @link = issue.issue_template_links.find { |linked| linked.element.equal?(element) }
        @kind = @link ? @link.kind(issue) : :select
      end

      def multiple?
        @link&.multiple?(@issue) || false
      end

      # The choices of a select: [label, value].
      def choices
        @link ? @link.choices(@issue) : @element.options.map { |option| [option.to_s, option.to_s] }
      end
    end
  end
end
