# frozen_string_literal: true

require 'yaml'

module RedmineIssueTemplate
  # Reads the files of a template folder (path => content) into a TemplateSet.
  # Each file is checked on its own: a file with errors is reported and left
  # out, the others still work.
  module Parser
    # Keys that YAML reads as booleans; GitHub forbids them as keys.
    BOOLEAN_WORDS = %w[y Y yes Yes YES n N no No NO true True TRUE false False FALSE on On ON off Off OFF].freeze

    module_function

    # files: { "bug.yml" => "...", "config.yml" => "..." } (paths in the folder)
    def parse(files)
      templates = []
      config = nil
      messages = []
      files.sort_by { |path, _| sort_key(path) }.each do |path, content|
        case kind(path)
        when :config
          config = ChooserConfig.parse(path, content)
          messages.concat(config.messages)
        when :form
          template = IssueForm.parse(path, content)
          templates << template
          messages.concat(template.messages)
        when :markdown
          template = MarkdownTemplate.parse(path, content)
          templates << template
          messages.concat(template.messages)
        end
      end
      check_unique_names(templates, messages)
      TemplateSet.new(templates: templates, config: config || ChooserConfig.default, messages: messages)
    end

    def kind(path)
      name = File.basename(path)
      return :config if ['config.yml', 'config.yaml'].include?(name)
      return :form if name.end_with?('.yml', '.yaml')
      return :markdown if name.end_with?('.md')

      nil
    end

    # GitHub lists YAML forms before Markdown templates, each alphanumerically.
    def sort_key(path)
      [kind(path) == :markdown ? 1 : 0, File.basename(path)]
    end

    # Template names must be unique among all templates (GitHub's rule).
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
      if forbidden_key?(data)
        errors << Message.error(path, :forbidden_key)
        return nil
      end
      data
    rescue Psych::Exception => e
      errors << Message.error(path, :invalid_yaml, detail: e.message.lines.first.to_s.strip)
      nil
    end

    def forbidden_key?(data)
      case data
      when Hash then data.any? { |key, value| key == true || key == false || forbidden_key?(value) }
      when Array then data.any? { |value| forbidden_key?(value) }
      else false
      end
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

  # An error or a warning about a file, shown in the project settings.
  Message = Struct.new(:path, :level, :key, :params, keyword_init: true) do
    def self.error(path, key, **params)
      new(path: path, level: 'error', key: key.to_s, params: params.transform_keys(&:to_s))
    end

    def self.warning(path, key, **params)
      new(path: path, level: 'warning', key: key.to_s, params: params.transform_keys(&:to_s))
    end

    def error?
      level == 'error'
    end

    def to_h
      { 'path' => path, 'level' => level, 'key' => key, 'params' => params }
    end

    def self.from_h(hash)
      new(path: hash['path'], level: hash['level'], key: hash['key'], params: hash['params'] || {})
    end

    # The text in the user's language (config/locales: issue_template_message_<key>).
    def text
      ::I18n.t("issue_template_message_#{key}", **params.symbolize_keys, default: key)
    end
  end
end
