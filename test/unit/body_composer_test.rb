# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class BodyComposerTest < ActiveSupport::TestCase
    include RedmineIssueTemplate::TestHelper

    def form
      RedmineIssueTemplate::Parser.parse('bug_report.yml' => github_fixture('bug_report.yml')).usable.first
    end

    def composer(answers, files: {})
      RedmineIssueTemplate::BodyComposer.new(form, answers, files: files)
    end

    test 'the answers are written into the description under a heading per field' do
      answers = { 'contact' => '', 'what-happened' => "It crashed.\n", 'version' => '1', 'browsers' => %w[0 2],
                  'logs' => 'Error: boom', 'terms' => ['0'] }
      expected = <<~MARKDOWN.chomp
        ### Contact Details

        _No response_

        ### What happened?

        It crashed.

        ### Version

        1.0.3 (Edge)

        ### What browsers are you seeing the problem on?

        Firefox, Safari

        ### Relevant log output

        ```shell
        Error: boom
        ```

        ### Code of Conduct

        - [X] I agree to follow this project's Code of Conduct

        ### Upload screenshots

        _No response_
      MARKDOWN
      assert_equal expected, composer(answers).compose
    end

    test 'empty answers, unchecked boxes and uploaded files' do
      body = composer({ 'terms' => [''] }, files: { 'screenshots' => ['screen shot.png'] }).compose
      assert_includes body, "### Relevant log output\n\n_No response_"
      assert_includes body, "- [ ] I agree to follow this project's Code of Conduct"
      assert_includes body, "### Upload screenshots\n\nattachment:\"screen shot.png\""
    end

    test 'required fields, required options and minimum length' do
      problems = composer({}).problems.map { |element, problem| [element.ref, problem] }
      assert_equal([%w[what-happened blank], %w[version blank], %w[terms unchecked]], problems.map do |r, p|
        [r, p.to_s]
      end)

      answers = { 'what-happened' => 'x', 'version' => '0', 'terms' => ['0'] }
      assert_equal [], composer(answers).problems
    end

    test 'min_length counts the characters of a given answer' do
      short = RedmineIssueTemplate::Parser.parse(
        'f.yml' => "name: Form\ndescription: d\nbody:\n- type: input\n  id: a\n  attributes:\n    label: A\n  " \
                   "validations:\n    min_length: 5\n"
      ).usable.first
      assert_equal [:too_short], RedmineIssueTemplate::BodyComposer.new(short, { 'a' => 'abc' }).problems.map(&:last)
      assert_equal [], RedmineIssueTemplate::BodyComposer.new(short, { 'a' => '' }).problems
    end

    test 'the form starts with the values and defaults of the template' do
      c = composer({})
      elements = form.elements
      assert_equal 'A bug happened!', c.value(elements[2])
      assert_equal '0', c.value(elements[3])
      assert_equal [], c.value(elements[4])
      assert_equal [], c.value(elements[6])
      assert_equal 'Other', composer({ 'contact' => 'Other' }).value(elements[1])
    end
  end
end
