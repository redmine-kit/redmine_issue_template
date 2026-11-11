# frozen_string_literal: true

require 'yaml'

module RedmineIssueTemplate
  # Reads the files of a template folder (path => content) into a TemplateSet.
  # Each file is checked on its own: a file with errors is reported and left
  # out, the others still work.
  module Parser
    module_function

    # The longest file, as IssueTemplateFile stores it.
    MAX_LENGTH = 65_535
    # Stands for a file the repository has but that is not read, being longer
    # in bytes than MAX_LENGTH characters can be.
    TOO_LONG = (' ' * (MAX_LENGTH + 1)).freeze

    # files: { "bug.yml" => "...", "config.yml" => "..." } (paths in the folder)
    def parse(files)
      templates = []
      configs = []
      messages = []
      files.sort_by { |path, _| sort_key(path) }.each do |path, content|
        file = parse_file(path, content, messages)
        (file.is_a?(ChooserConfig) ? configs : templates) << file if file
      end
      check_unique_names(templates, messages)
      check_unique_keys(templates, messages)
      TemplateSet.new(templates: templates, config: configs.last || ChooserConfig.default, messages: messages)
    end

    # The file read by its kind, with its messages added to messages; nil
    # for a file too long or of no kind.
    def parse_file(path, content, messages)
      if content.to_s.length > MAX_LENGTH
        messages << Message.error(path, :file_too_long, count: MAX_LENGTH)
        return nil
      end

      reader = { config: ChooserConfig, form: IssueForm, markdown: MarkdownTemplate }[kind(path)]
      return nil unless reader

      file = reader.parse(path, content)
      messages.concat(file.messages)
      file
    end

    def kind(path)
      name = File.basename(path)
      return :config if ['config.yml', 'config.yaml'].include?(name)
      return :form if name.end_with?('.yml', '.yaml')
      return :markdown if name.end_with?('.md')

      nil
    end

    # YAML forms come before Markdown templates, each alphanumerically.
    def sort_key(path)
      [kind(path) == :markdown ? 1 : 0, File.basename(path)]
    end

    # Two files can't have the same id in URLs (bug.yml and bug.md): the
    # first in the chooser's order keeps it.
    def check_unique_keys(templates, messages)
      templates.group_by(&:key).each_value do |same|
        same.drop(1).each do |template|
          template.errors << Message.error(template.path, :duplicate_key, key: template.key)
          messages << template.errors.last
        end
      end
    end

    # Template names must be unique among all templates.
    def check_unique_names(templates, messages)
      templates.group_by(&:name).each do |name, same|
        next if name.blank? || same.size < 2

        same.drop(1).each do |template|
          template.errors << Message.error(template.path, :duplicate_name, name: name)
          messages << template.errors.last
        end
      end
    end

    # YAML with only plain data. Errors become messages of the file.
    def load_yaml(path, content, errors)
      data = YAML.safe_load(content.to_s, permitted_classes: [], aliases: false)
      key = YamlNodes.forbidden_key(Psych.parse(content.to_s))
      if key
        errors << Message.error(path, :forbidden_key, key: key)
        return nil
      end
      data
    # Deeply nested YAML exhausts the stack (SystemStackError is not a
    # StandardError, and would stop the repository's fetch).
    rescue Psych::Exception, SystemStackError
      errors << Message.error(path, :invalid_yaml)
      nil
    end

    # The first value that appears twice, or nil.
    def duplicate(values)
      values.tally.find { |_, count| count > 1 }&.first
    end

    # A list given as an array or a comma-separated string (labels, assignees).
    def list(value)
      case value
      when Array then value.map(&:to_s).map(&:strip).compact_blank
      when String then value.split(',').map(&:strip).compact_blank
      else []
      end
    end
  end
end
