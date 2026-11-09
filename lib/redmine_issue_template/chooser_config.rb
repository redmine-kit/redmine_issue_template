# frozen_string_literal: true

module RedmineIssueTemplate
  # config.yml of the template folder: whether blank issues are allowed and
  # the contact links shown in the chooser (GitHub's "Configuring the
  # template chooser").
  class ChooserConfig
    KEYS = %w[blank_issues_enabled contact_links].freeze
    LINK_KEYS = %w[name url about].freeze

    ContactLink = Struct.new(:name, :url, :about, keyword_init: true)

    attr_reader :path, :contact_links, :messages

    def self.default
      new(nil)
    end

    def self.parse(path, content)
      config = new(path)
      config.read(content.to_s)
      config
    end

    def initialize(path)
      @path = path
      @blank_issues_enabled = true
      @contact_links = []
      @messages = []
    end

    # GitHub's default is true: the chooser offers a blank issue.
    def blank_issues_enabled?
      @blank_issues_enabled
    end

    def read(content)
      data = Parser.load_yaml(path, content, @messages)
      return if data.nil?
      return @messages << Message.error(path, :config_not_map) unless data.is_a?(Hash)

      (data.keys.map(&:to_s) - KEYS).each { |key| @messages << Message.warning(path, :config_unknown_key, key: key) }
      read_blank(data)
      read_links(data['contact_links'])
    end

    private

    def read_blank(data)
      return unless data.key?('blank_issues_enabled')

      value = data['blank_issues_enabled']
      if [true, false].include?(value)
        @blank_issues_enabled = value
      else
        @messages << Message.error(path, :invalid_value, key: 'blank_issues_enabled')
      end
    end

    def read_links(links)
      return if links.nil?
      return @messages << Message.error(path, :invalid_value, key: 'contact_links') unless links.is_a?(Array)

      links.each_with_index do |link, index|
        unless link.is_a?(Hash) && LINK_KEYS.all? { |key| link[key].is_a?(String) && link[key].present? }
          @messages << Message.error(path, :invalid_contact_link, index: index)
          next
        end
        unless link['url'].match?(%r{\Ahttps?://}i)
          @messages << Message.error(path, :invalid_contact_url, index: index)
          next
        end
        @contact_links << ContactLink.new(name: link['name'], url: link['url'], about: link['about'])
      end
    end
  end
end
