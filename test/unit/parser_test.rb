# frozen_string_literal: true

require_relative '../test_helper'

module RedmineIssueTemplate
  class ParserTest < ActiveSupport::TestCase
    include RedmineIssueTemplate::TestHelper

    def parse(files)
      RedmineIssueTemplate::Parser.parse(files)
    end

    def errors_of(set, path)
      set.messages.select { |m| m.path == path && m.error? }.map(&:key)
    end

    test 'the example templates parse without errors' do
      set = parse(github_files)
      assert_equal([], set.messages.select(&:error?).map { |m| [m.path, m.key] })
      assert_equal %w[bug_report bug], set.usable.map(&:key)
      # The converted form has the Markdown template's name on purpose, so it
      # replaces the Markdown template: the two together are an error.
      converted = parse('bug_converted.yml' => github_fixture('bug_converted.yml'))
      assert_equal [], converted.messages.select(&:error?).map(&:key)
      assert_equal %w[duplicate_name], errors_of(parse('a.yml' => github_fixture('bug_converted.yml'),
                                                       'b.md' => github_fixture('bug.md')), 'b.md')
    end

    test 'issue forms come before Markdown templates, each alphanumerically' do
      form = "name: Form\ndescription: d\nbody:\n- type: input\n  attributes:\n    label: L\n"
      markdown = "---\nname: Markdown\nabout: a\n---\nBody\n"
      set = parse('2-b.md' => markdown, '1-a.md' => markdown.sub('Markdown', 'Markdown 1'), '3-c.yml' => form)
      assert_equal %w[3-c 1-a 2-b], set.usable.map(&:key)
    end

    test 'the bug report form has every element of the example' do
      form = parse('bug_report.yml' => github_fixture('bug_report.yml')).usable.first
      assert form.form?
      assert_equal 'Bug Report', form.name
      assert_equal 'File a bug report.', form.about
      assert_equal '[Bug]: ', form.title
      assert_equal %w[bug triage], form.labels
      assert_equal %w[octo-org/1 octo-org/44], form.projects
      assert_equal %w[octocat], form.assignees
      assert_equal 'bug', form.type
      assert_equal %w[markdown input textarea dropdown dropdown textarea checkboxes upload], form.elements.map(&:type)
      assert_equal %w[contact what-happened version browsers logs terms screenshots], form.fields.map(&:ref)
      assert form.elements[2].required?
      assert form.elements[4].multiple?
      assert_equal [{ label: "I agree to follow this project's Code of Conduct", required: true }],
                   form.elements[6].checkbox_options
    end

    test 'the Markdown template has its front matter and body' do
      template = parse('bug.md' => github_fixture('bug.md')).usable.first
      assert_not template.form?
      assert_equal '🐞 Bug', template.name
      assert_equal 'File a bug/issue', template.about
      assert_equal '[BUG] <title>', template.title
      assert_equal ['Bug', 'Needs Triage'], template.labels
      assert_equal [], template.assignees
      assert_match(/\A<!--\nNote: Please search/, template.body)
      assert_includes template.body, '### Steps To Reproduce:'
    end

    test 'config.yml sets the chooser' do
      config = parse('config.yml' => github_fixture('config.yml')).config
      assert_not config.blank_issues_enabled?
      assert_equal ['GitHub Community Support', 'GitHub Security Bug Bounty'], config.contact_links.map(&:name)
      assert_equal 'https://bounty.github.com/', config.contact_links.last.url
    end

    test 'blank issues are enabled without config.yml' do
      assert parse({}).config.blank_issues_enabled?
    end

    test 'a Markdown template needs front matter with name and about' do
      set = parse('a.md' => "Just text\n", 'b.md' => "---\nname: B\n---\nText\n")
      assert_equal %w[no_front_matter], errors_of(set, 'a.md')
      assert_equal %w[missing_key], errors_of(set, 'b.md')
      assert_not set.any?
    end

    INPUT = "- type: input\n  attributes:\n    label: L\n"

    # An issue form with the given body elements (YAML list items).
    def form(*elements)
      "name: Form\ndescription: d\nbody:\n#{elements.join}"
    end

    def dropdown(options, extra = '')
      "- type: dropdown\n  attributes:\n    label: L\n    options: #{options}\n#{extra}"
    end

    test 'the rules for issue forms' do
      cases = {
        "description: d\nbody:\n#{INPUT}" => %w[missing_key],
        "name: Form\ndescription: d\ninput: x\nbody:\n#{INPUT}" => %w[not_permitted_key],
        "name: Form\ndescription: d\nbody: []\n" => %w[body_empty],
        form("- type: markdown\n  attributes:\n    value: Hi\n") => %w[body_no_field],
        form("- attributes:\n    label: L\n") => %w[missing_type],
        form("- type: x\n  attributes:\n    label: L\n") => %w[invalid_type],
        form("- type: markdown\n  attributes: {}\n", INPUT) => %w[missing_attribute],
        form("- type: input\n  id: a b\n  attributes:\n    label: L\n") => %w[invalid_id],
        form("- type: input\n  id: a\n  attributes:\n    label: L\n",
             "- type: input\n  id: a\n  attributes:\n    label: M\n") => %w[ids_not_unique],
        form(INPUT, "- type: textarea\n  attributes:\n    label: L\n") => %w[labels_not_unique],
        form("- type: input\n  attributes:\n    label: A b\n",
             "- type: input\n  attributes:\n    label: a-b\n") => %w[labels_too_similar],
        form("#{INPUT}    foo: x\n") => %w[attribute_key],
        form("#{INPUT}  validations:\n    accept: x\n") => %w[validation_key],
        form("#{INPUT}  validations:\n    min_length: -1\n") => %w[invalid_validation],
        form(dropdown('[a, a]')) => %w[options_not_unique],
        form(dropdown('[None, b]')) => %w[options_none],
        form(dropdown('[yes, b]')) => %w[options_boolean],
        form(dropdown('[a]', "    default: 3\n")) => %w[invalid_default],
        form("- type: checkboxes\n  attributes:\n    label: L\n    options:\n    - label: a\n    - label: a\n") =>
          %w[checkboxes_not_unique],
        "name: Bug\ndescription: d\nbody:\n#{INPUT}" => %w[name_too_short],
        "name: Form\ndescription: d\nyes: 1\nbody:\n#{INPUT}" => %w[forbidden_key],
        "name: Form\n  description: [\n" => %w[invalid_yaml]
      }
      cases.each do |content, keys|
        set = parse('form.yml' => content)
        assert_equal keys, errors_of(set, 'form.yml'), content
        assert_not set.any?, content
      end
    end

    def texts(content, path = 'form.yml')
      parse(path => content).messages.map(&:text)
    end

    test 'files that are too deep, too long or share an id' do
      deep = "name: Deep\ndescription: d\nbody: #{'[' * 20_000}#{']' * 20_000}\n"
      assert_equal %w[invalid_yaml], errors_of(parse('deep.yml' => deep), 'deep.yml')
      long = "---\nname: Long\nabout: a\n---\n#{'x' * RedmineIssueTemplate::Parser::MAX_LENGTH}"
      assert_equal %w[file_too_long], errors_of(parse('long.md' => long), 'long.md')
      set = parse('bug.yml' => github_fixture('bug_report.yml'), 'bug.md' => github_fixture('bug.md'))
      assert_equal %w[duplicate_key], errors_of(set, 'bug.md')
      assert_equal 'bug.yml', set.find('bug').path
    end

    test 'links of form fields' do
      form = lambda do |elements|
        "name: Form\ndescription: d\nbody:\n#{elements}"
      end
      linked = "- link: fixed_version\n  attributes:\n    label: Version\n"
      set = parse('a.yml' => form.call(linked))
      assert_equal [], errors_of(set, 'a.yml')
      assert_equal 'fixed_version', set.usable.first.fields.first.link

      # A field with a link has no type.
      typed = "- type: dropdown\n  link: category\n  attributes:\n    label: C\n"
      assert_equal %w[not_with_link], errors_of(parse('a.yml' => form.call(typed)), 'a.yml')
      assert_equal %w[links_not_unique],
                   errors_of(parse('a.yml' => form.call(linked + linked.sub('Version', 'Again'))), 'a.yml')
      # Fields without an id and with labels without Latin letters get their place as their name.
      japanese = "- type: input\n  attributes:\n    label: 何が起きましたか？\n- type: input\n  attributes:\n    label: 環境\n"
      fields = parse('a.yml' => form.call(japanese)).usable.first.fields
      assert_equal %w[field-0 field-1], fields.map(&:ref)
      # is_private and priority always have a value: they can't be required.
      required = "name: Form\ndescription: d\nfields:\n  is_private: required\nbody:\n#{japanese}"
      assert_equal %w[redmine_invalid_visibility], errors_of(parse('a.yml' => required), 'a.yml')
    end

    test 'messages read like Redmine validation errors' do
      assert_equal ['form.yml: description cannot be blank'], texts("name: Form\nbody:\n#{INPUT}")
      assert_equal ['form.yml is not valid YAML'], texts("name: Form\n  description: [\n")
      assert_equal ['form.yml is invalid'], texts("- a\n")
      assert_equal ['form.yml: name is too short (minimum is 4 characters)'],
                   texts("name: Bug\ndescription: d\nbody:\n#{INPUT}")
      assert_equal ['form.yml: body[0]: options: a has already been taken'], texts(form(dropdown('[a, a]')))
      assert_equal ['config.yml: contact_links[0]: url cannot be blank'],
                   texts("contact_links:\n- name: A\n  about: b\n", 'config.yml')
    end

    test 'keys and options YAML reads as booleans are named as written' do
      assert_equal ['form.yml: On must be quoted'], texts("name: Form\ndescription: d\nOn: 1\nbody:\n#{INPUT}")
      assert_equal ['form.yml: body[0]: options: yes must be quoted'], texts(form(dropdown('[a, yes]')))
    end

    test 'messages in Japanese' do
      ::I18n.with_locale(:ja) do
        assert_equal ['form.yml: description を入力してください'], texts("name: Form\nbody:\n#{INPUT}")
        assert_equal ['form.yml は正しい YAML ではありません'], texts("name: Form\n  description: [\n")
        assert_equal ['form.yml: yes は引用符で囲んでください'], texts("name: Form\ndescription: d\nyes: 1\nbody:\n#{INPUT}")
        assert_equal ['form.yml: name は4文字以上で入力してください'], texts("name: Bug\ndescription: d\nbody:\n#{INPUT}")
      end
    end

    test "Redmine's keys are top-level keys of a form" do
      form = "name: Form\ndescription: d\ntracker: Bug\npriority: High\nfields:\n  due_date: required\nbody:\n#{INPUT}"
      set = parse('form.yml' => form)
      assert_equal [], errors_of(set, 'form.yml')
      assert_equal 'Bug', set.usable.first.options.tracker
      assert_equal %w[not_permitted_key], errors_of(parse('form.yml' => "redmine: {}\n#{form}"), 'form.yml')
    end

    test 'a file with errors leaves the others usable' do
      set = parse('broken.yml' => "name: x\n", 'bug.md' => github_fixture('bug.md'))
      assert_equal %w[bug], set.usable.map(&:key)
      assert errors_of(set, 'broken.yml').any?
    end

    test 'template names must be unique' do
      markdown = "---\nname: Same\nabout: a\n---\n"
      set = parse('a.md' => markdown, 'b.md' => markdown)
      assert_equal %w[a], set.usable.map(&:key)
      assert_equal %w[duplicate_name], errors_of(set, 'b.md')
    end

    test 'config.yml errors' do
      config = "blank_issues_enabled: maybe\ncontact_links:\n- name: A\n  url: ftp://x\n  about: b\n- name: B\n"
      set = parse('config.yml' => config)
      assert_equal %w[invalid_value invalid_contact_url invalid_contact_link], errors_of(set, 'config.yml')
      assert set.config.blank_issues_enabled?
    end

    test 'lists can be comma-separated strings' do
      assert_equal %w[a b], RedmineIssueTemplate::Parser.list('a, b')
      assert_equal [], RedmineIssueTemplate::Parser.list(nil)
    end
  end
end
