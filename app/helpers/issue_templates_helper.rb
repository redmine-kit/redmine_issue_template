# frozen_string_literal: true

module IssueTemplatesHelper
  # Only images of this site, by a path: a template's text is shown to
  # everyone who opens New issue, and another site would see each of them.
  # Other images become links.
  LOCAL_IMAGE = %r{\A(?![a-z][a-z0-9+.-]*:)(?![/\\]{2})[^\\\s][^\\]*\z}i
  EXTERNAL_IMAGES = Loofah::Scrubber.new do |node|
    next unless node.name == 'img' && !LOCAL_IMAGE.match?(node['src'].to_s)

    link = Nokogiri::XML::Node.new('a', node.document)
    link['href'] = node['src']
    link.content = node['alt'].presence || node['src']
    node.replace(link)
  end

  # A template's Markdown (descriptions, the labels of checkbox options)
  # with Redmine's CommonMark formatter, which sanitizes it. inline: for a
  # place inside a line, paragraphs joined by line breaks.
  def issue_template_markdown(text, inline: false)
    html = Redmine::WikiFormatting.to_html('common_mark', text.to_s)
    html = Loofah.html5_fragment(html).scrub!(EXTERNAL_IMAGES).to_s
    html = inline_html(html) if inline
    html.html_safe
  end

  # A field's label, marked when validations.required is set.
  def issue_template_label(element, field_id)
    label_tag(field_id) do
      safe_join([element.label, (content_tag(:span, ' *', class: 'required') if element.required?)].compact)
    end
  end

  # A field's description, under it.
  def issue_template_info(element)
    text = element.attributes['description']
    content_tag(:em, issue_template_markdown(text, inline: true), class: 'info') if text.present?
  end

  private

  # Paragraphs only: joined by line breaks. Anything else (lists, code)
  # stays as it is.
  def inline_html(html)
    paragraphs = html.strip.scan(%r{<p>(.*?)</p>}m).flatten
    return html unless html.strip.gsub(%r{<p>.*?</p>}m, '').strip.empty? && paragraphs.any?

    paragraphs.join('<br><br>')
  end
end
