# frozen_string_literal: true

module RedmineIssueTemplate
  # The answers of an issue form, written into the issue's description: a
  # "### <label>" heading per field and the answer below it.
  class BodyComposer
    NO_RESPONSE = '_No response_'

    # answers: { ref => a string, or option indexes for multiple dropdowns and
    # checkboxes }. files: { ref => file names } of upload fields. linked: fields
    # that set the issue's fields instead. dropped: fields the form leaves out.
    def initialize(form, answers, files: {}, linked: [], dropped: [])
      @form = form
      @answers = (answers || {}).to_h.transform_keys(&:to_s)
      @files = files
      @linked = linked
      @dropped = dropped
    end

    def compose
      fields = @form.fields.reject { |element| @linked.include?(element) || @dropped.include?(element) }
      fields.map { |element| "### #{element.label}\n\n#{answer(element)}" }.join("\n\n")
    end

    # The fields whose answer breaks a validation: [[element, :blank], ...].
    def problems
      (@form.fields - @dropped).each_with_object([]) do |element, problems|
        problem = problem(element)
        problems << [element, problem] if problem
      end
    end

    # The value the form shows for a field: the answer, or the template's
    # value or default when nothing was posted yet.
    def value(element)
      return @answers[element.ref] if @answers.key?(element.ref)

      case element.type
      when 'dropdown' then if element.attributes['default'].nil?
                             element.multiple? ? [] : nil
                           else
                             default_value(element)
                           end
      when 'checkboxes' then []
      else element.attributes['value'].to_s
      end
    end

    private

    def default_value(element)
      element.multiple? ? [element.attributes['default'].to_s] : element.attributes['default'].to_s
    end

    def answer(element)
      text = case element.type
             when 'textarea' then textarea(element)
             when 'input' then raw(element).to_s.strip
             when 'dropdown' then chosen(element).join(', ')
             when 'checkboxes' then checkboxes(element)
             when 'upload' then files(element).map { |name| "attachment:\"#{name}\"" }.join("\n")
             when IssueForm::LINK then given(element).join(', ')
             end
      text.presence || NO_RESPONSE
    end

    def raw(element)
      @answers[element.ref]
    end

    def textarea(element)
      text = raw(element).to_s.strip
      return text if text.empty? || element.attributes['render'].blank?

      "```#{element.attributes['render']}\n#{text}\n```"
    end

    # The chosen options' labels. Indexes beyond any list are ignored.
    def chosen(element)
      Array(raw(element)).filter_map do |index|
        element.options[index.to_i]&.to_s if index.to_s.match?(/\A\d{1,6}\z/)
      end
    end

    # The answer's non-blank values: a linked field's value or values.
    def given(element)
      Array(raw(element)).map { |value| value.to_s.strip }.reject(&:empty?)
    end

    def checked(element)
      Array(raw(element)).map(&:to_s).reject(&:empty?)
    end

    def checkboxes(element)
      element.checkbox_options.each_with_index.map do |option, index|
        "- [#{checked(element).include?(index.to_s) ? 'X' : ' '}] #{option[:label]}"
      end.join("\n")
    end

    def problem(element)
      case element.type
      when 'textarea', 'input' then text_problem(element)
      when 'dropdown' then blank_problem(element, chosen(element))
      when 'checkboxes' then checkbox_problem(element)
      when 'upload' then upload_problem(element)
      when IssueForm::LINK then blank_problem(element, given(element))
      end
    end

    def files(element)
      @files.fetch(element.ref, [])
    end

    def upload_problem(element)
      return :not_accepted unless files(element).all? { |name| element.accepts?(name) }

      blank_problem(element, files(element))
    end

    def blank_problem(element, values)
      :blank if element.required? && values.empty?
    end

    def text_problem(element)
      text = raw(element).to_s.strip
      return :blank if element.required? && text.empty?
      return :too_short if element.min_length && !text.empty? && text.length < element.min_length

      nil
    end

    def checkbox_problem(element)
      return :blank if element.required? && checked(element).empty?

      missing = element.checkbox_options.each_with_index.any? do |option, index|
        option[:required] && !checked(element).include?(index.to_s)
      end
      :unchecked if missing
    end
  end
end
