# frozen_string_literal: true

module RedmineIssueTemplate
  # The YAML text as it is written, for what loading it loses: keys and
  # values such as yes or on, which YAML reads as true or false.
  module YamlNodes
    # Words that YAML reads as booleans; GitHub forbids them as keys.
    BOOLEAN_WORDS = %w[y Y yes Yes YES n N no No NO true True TRUE false False FALSE on On ON off Off OFF].freeze

    module_function

    # The first key written as a word that YAML reads as true or false, as
    # it is written in the file.
    def forbidden_key(node)
      case node
      when Psych::Nodes::Mapping
        node.children.each_slice(2) do |key, value|
          return key.value if boolean_word?(key)

          found = forbidden_key(value)
          return found if found
        end
      when Psych::Nodes::Node
        node.children.to_a.each do |child|
          found = forbidden_key(child)
          return found if found
        end
      end
      nil
    end

    def scalar?(node, value)
      node.is_a?(Psych::Nodes::Scalar) && node.value == value
    end

    # An unquoted scalar such as yes, on or true.
    def boolean_word?(node)
      node.is_a?(Psych::Nodes::Scalar) && node.plain && BOOLEAN_WORDS.include?(node.value)
    end

    # The node at a path of keys and indexes in the YAML text, or nil.
    def yaml_node(content, *steps)
      node = Psych.parse(content.to_s)&.root
      steps.each do |step|
        node = case node
               when Psych::Nodes::Mapping
                 node.children.each_slice(2).find { |key, _| scalar?(key, step.to_s) }&.last
               when Psych::Nodes::Sequence
                 step.is_a?(Integer) ? node.children[step] : nil
               end
      end
      node
    rescue Psych::Exception
      nil
    end
  end
end
