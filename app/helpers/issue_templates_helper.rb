# frozen_string_literal: true

module IssueTemplatesHelper
  # Images from other sites become links: a template's text is shown to
  # everyone who opens New issue, and the site would see each of them.
  EXTERNAL_IMAGES = Loofah::Scrubber.new do |node|
    next unless node.name == 'img' && node['src'].to_s.match?(%r{\A(?:https?:)?//}i)

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
    html = Loofah.fragment(html).scrub!(EXTERNAL_IMAGES).to_s
    html = inline_html(html) if inline
    html.html_safe
  end

  private

  def inline_html(html)
    html.strip.sub(/\A<p>/, '').sub(%r{</p>\z}, '').gsub(%r{</p>\s*<p>}, '<br><br>')
  end
end
