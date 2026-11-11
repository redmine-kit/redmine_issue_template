# frozen_string_literal: true

require_relative '../test_helper'

class IssueTemplatesHelperTest < Redmine::HelperTest
  include IssueTemplatesHelper

  # src => kept as an image
  IMAGES = {
    '/attachments/download/1/a.png' => true,
    'images/a.png' => true,
    'https://example.com/a.png' => false,
    'http://example.com/a.png' => false,
    '//example.com/a.png' => false,
    '/\\example.com/a.png' => false,
    '\\\\example.com/a.png' => false,
    'https:/\\example.com/a.png' => false,
    ' https://example.com/a.png' => false
  }.freeze

  test 'only images of this site by a path stay images' do
    IMAGES.each do |src, kept|
      assert_equal kept, IssueTemplatesHelper::LOCAL_IMAGE.match?(src), src.inspect
    end
  end

  test 'images from other sites become links' do
    html = issue_template_markdown('![pixel](https://tracker.example/p.gif)')
    assert_not_includes html, '<img'
    assert_includes html, '<a href="https://tracker.example/p.gif">pixel</a>'
  end

  test 'inline Markdown joins paragraphs and keeps lists' do
    assert_equal 'a<br><br>b', issue_template_markdown("a\n\nb", inline: true)
    assert_includes issue_template_markdown("a\n\n- b\n- c", inline: true), '<ul>'
  end

  test 'Markdown is sanitized' do
    html = issue_template_markdown("<script>alert(1)</script>\n\n[x](javascript:alert(1))")
    assert_not_includes html, '<script'
    assert_not_includes html, 'href="javascript'
  end
end
