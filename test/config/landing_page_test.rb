require 'test_helper'

class LandingPageTest < ActiveSupport::TestCase
  setup do
    @document = Nokogiri::HTML5(File.read(Rails.root.join('public/index.html')))
  end

  test 'is valid HTML without leaked demo source' do
    assert_empty @document.errors
    refute_includes @document.text, 'tech: { name:'
  end

  test 'uses the production domain in social metadata' do
    assert_equal 'https://no-fluff.brandymint.ru/', meta_content('meta[property="og:url"]')
    assert_includes meta_content('meta[property="og:image"]'), 'no-fluff.brandymint.ru'
    assert_includes meta_content('meta[name="twitter:image"]'), 'no-fluff.brandymint.ru'
  end

  test 'Telegram calls to action open the production bot' do
    calls_to_action = @document.css('a.button[href*="t.me/"]')

    assert_operator calls_to_action.size, :>=, 3
    calls_to_action.each do |link|
      assert_match %r{\Ahttps://t\.me/bez_sheluhi_bot}, link['href']
    end
  end

  test 'product demo tabs reference accessible panels' do
    tabs = @document.css('[role="tab"]')
    panels = @document.css('[role="tabpanel"]')

    assert_equal 3, tabs.size
    assert_equal 3, panels.size
    tabs.each do |tab|
      panel = @document.at_css("##{tab['aria-controls']}")
      assert panel
      assert_equal tab['id'], panel['aria-labelledby']
    end
  end

  private

  def meta_content(selector)
    @document.at_css(selector)&.[]('content')
  end
end
