# frozen_string_literal: true

module IssueTemplatesHelper
  # A template's Markdown (the description of a field and the labels of
  # checkbox options are Markdown) with Redmine's CommonMark formatter, which
  # sanitizes it. inline: without the enclosing paragraph.
  def issue_template_markdown(text, inline: false)
    html = Redmine::WikiFormatting.to_html('common_mark', text.to_s)
    html = html.strip.sub(%r{\A<p>(.*)</p>\z}m, '\1') if inline
    html.html_safe
  end
end
