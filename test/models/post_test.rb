require 'test_helper'

class PostTest < ActiveSupport::TestCase
  # Association tests
  test 'should belong to channel' do
    post = posts(:one)
    assert_respond_to post, :channel
  end

  test 'should belong to classified_by_session optionally' do
    post = posts(:one)
    assert_respond_to post, :classified_by_session
  end

  test 'should have many user_digest_items' do
    post = posts(:one)
    assert_respond_to post, :user_digest_items
  end

  test 'should have many user_digests through user_digest_items' do
    post = posts(:one)
    assert_respond_to post, :user_digests
  end

  test 'should have many feedbacks' do
    post = posts(:one)
    assert_respond_to post, :feedbacks
  end

  test 'should have many post_classifications' do
    post = posts(:one)
    assert_respond_to post, :post_classifications
  end

  test 'should destroy associated user_digest_items when destroyed' do
    post = posts(:one)
    assert_difference 'UserDigestItem.count', -1 do
      post.destroy
    end
  end

  # Validation tests
  test 'should be valid with valid attributes' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current
    )
    assert post.valid?
  end

  test 'should require telegram_message_id' do
    post = Post.new(
      channel: channels(:one),
      published_at: Time.current
    )
    assert_not post.valid?
    assert post.errors[:telegram_message_id].present?
  end

  test 'should require unique telegram_message_id scoped to channel_id' do
    existing_post = posts(:one)
    post = Post.new(
      channel: existing_post.channel,
      telegram_message_id: existing_post.telegram_message_id,
      published_at: Time.current
    )
    assert_not post.valid?
    assert post.errors[:telegram_message_id].present?
  end

  test 'should allow same telegram_message_id for different channels' do
    post1 = posts(:one)
    post = Post.new(
      channel: channels(:two),
      telegram_message_id: post1.telegram_message_id,
      published_at: Time.current
    )
    assert post.valid?
  end

  test 'should require published_at' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999
    )
    assert_not post.valid?
    assert post.errors[:published_at].present?
  end

  test 'should require importance_score to be greater than or equal to 0' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      importance_score: -1
    )
    assert_not post.valid?
    assert post.errors[:importance_score].present?
  end

  test 'should require importance_score to be less than or equal to 100' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      importance_score: 101
    )
    assert_not post.valid?
    assert post.errors[:importance_score].present?
  end

  test 'should accept importance_score of 0' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      importance_score: 0
    )
    assert post.valid?
  end

  test 'should accept importance_score of 100' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      importance_score: 100
    )
    assert post.valid?
  end

  # Scope tests
  test 'important scope should return posts with importance_score >= 60' do
    post = posts(:one)
    post.update(importance_score: 75)

    important_posts = Post.important
    assert_includes important_posts, post
  end

  test 'important scope should not return posts with importance_score < 60' do
    post = posts(:one)
    post.update(importance_score: 50)

    important_posts = Post.important
    assert_not_includes important_posts, post
  end

  test 'not_important scope should return posts with importance_score < 60' do
    post = posts(:one)
    post.update(importance_score: 40)

    not_important_posts = Post.not_important
    assert_includes not_important_posts, post
  end

  test 'not_important scope should not return posts with importance_score >= 60' do
    post = posts(:one)
    post.update(importance_score: 80)

    not_important_posts = Post.not_important
    assert_not_includes not_important_posts, post
  end

  test 'not_ads scope should return non-ad posts' do
    post = posts(:one)
    post.update(is_ad: false)

    non_ad_posts = Post.not_ads
    assert_includes non_ad_posts, post
  end

  test 'not_ads scope should not return ad posts' do
    post = posts(:one)
    post.update(is_ad: true)

    non_ad_posts = Post.not_ads
    assert_not_includes non_ad_posts, post
  end

  test 'ads scope should return ad posts' do
    post = posts(:one)
    post.update(is_ad: true)

    ad_posts = Post.ads
    assert_includes ad_posts, post
  end

  test 'ads scope should not return non-ad posts' do
    post = posts(:one)
    post.update(is_ad: false)

    ad_posts = Post.ads
    assert_not_includes ad_posts, post
  end

  test 'not_fluff scope should return non-fluff posts' do
    post = posts(:one)
    post.update(is_fluff: false)

    non_fluff_posts = Post.not_fluff
    assert_includes non_fluff_posts, post
  end

  test 'not_fluff scope should not return fluff posts' do
    post = posts(:one)
    post.update(is_fluff: true)

    non_fluff_posts = Post.not_fluff
    assert_not_includes non_fluff_posts, post
  end

  test 'unique scope should return posts without duplicates' do
    post = posts(:one)
    post.update(is_duplicate_of: nil)

    unique_posts = Post.unique
    assert_includes unique_posts, post
  end

  test 'unique scope should not return duplicate posts' do
    post = posts(:one)
    post.update(is_duplicate_of: posts(:two).id)

    unique_posts = Post.unique
    assert_not_includes unique_posts, post
  end

  test 'duplicates scope should return duplicate posts' do
    post = posts(:one)
    post.update(is_duplicate_of: posts(:two).id)

    duplicate_posts = Post.duplicates
    assert_includes duplicate_posts, post
  end

  test 'duplicates scope should not return unique posts' do
    post = posts(:one)
    post.update(is_duplicate_of: nil)

    duplicate_posts = Post.duplicates
    assert_not_includes duplicate_posts, post
  end

  test 'recent scope should return posts published in last 7 days' do
    post = posts(:one)
    post.update(published_at: 3.days.ago)

    recent_posts = Post.recent
    assert_includes recent_posts, post
  end

  test 'recent scope should not return posts published more than 7 days ago' do
    post = posts(:one)
    post.update(published_at: 8.days.ago)

    recent_posts = Post.recent
    assert_not_includes recent_posts, post
  end

  test 'by_published_at scope should order posts by published_at descending' do
    post1 = posts(:one)
    post1.update(published_at: 2.days.ago)

    post2 = posts(:two)
    post2.update(published_at: 1.day.ago)

    ordered_posts = Post.by_published_at
    assert_equal post2, ordered_posts.first
    assert_equal post1, ordered_posts.second
  end

  test 'by_importance scope should order posts by importance_score descending' do
    post1 = posts(:one)
    post1.update(importance_score: 50)

    post2 = posts(:two)
    post2.update(importance_score: 90)

    ordered_posts = Post.by_importance
    assert_equal post2, ordered_posts.first
    assert_equal post1, ordered_posts.second
  end

  test 'for_channel scope should return posts for specific channel' do
    channel = channels(:one)
    post = posts(:one)

    channel_posts = Post.for_channel(channel)
    assert_includes channel_posts, post
  end

  test 'for_channel scope should not return posts for other channels' do
    channel1 = channels(:one)
    post2 = posts(:two)

    channel1_posts = Post.for_channel(channel1)
    assert_not_includes channel1_posts, post2
  end

  test 'by_topic scope should return posts with specific topic' do
    post = posts(:one)
    post.update(topics: [ 'ruby', 'rails' ])

    ruby_posts = Post.by_topic('ruby')
    assert_includes ruby_posts, post
  end

  test 'by_topic scope should not return posts without specific topic' do
    post = posts(:one)
    post.update(topics: [ 'python', 'django' ])

    ruby_posts = Post.by_topic('ruby')
    assert_not_includes ruby_posts, post
  end

  test 'classified scope should return posts with importance_score > 0' do
    post = posts(:one)
    post.update(importance_score: 50)

    classified_posts = Post.classified
    assert_includes classified_posts, post
  end

  test 'classified scope should not return posts with importance_score = 0' do
    post = posts(:one)
    post.update(importance_score: 0)

    classified_posts = Post.classified
    assert_not_includes classified_posts, post
  end

  test 'unclassified scope should return posts with importance_score = 0' do
    post = posts(:one)
    post.update(importance_score: 0)

    unclassified_posts = Post.unclassified
    assert_includes unclassified_posts, post
  end

  test 'unclassified scope should not return posts with importance_score > 0' do
    post = posts(:one)
    post.update(importance_score: 50)

    unclassified_posts = Post.unclassified
    assert_not_includes unclassified_posts, post
  end

  # Method tests
  test 'mark_as_duplicate! should set is_duplicate_of' do
    post1 = posts(:one)
    post2 = posts(:two)

    post1.mark_as_duplicate!(post2)
    post1.reload
    assert_equal post2.id, post1.is_duplicate_of
  end

  test 'mark_as_important! should set is_important to true' do
    post = posts(:one)
    post.update(is_important: false)

    post.mark_as_important!
    post.reload
    assert post.is_important
  end

  test 'mark_as_ad! should set is_ad to true' do
    post = posts(:one)
    post.update(is_ad: false)

    post.mark_as_ad!
    post.reload
    assert post.is_ad
  end

  test 'mark_as_fluff! should set is_fluff to true' do
    post = posts(:one)
    post.update(is_fluff: false)

    post.mark_as_fluff!
    post.reload
    assert post.is_fluff
  end

  test 'has_media? should return true when media_urls is present and not empty' do
    post = posts(:one)
    post.update(media_urls: [ 'https://example.com/image.jpg' ])

    assert post.has_media?
  end

  test 'has_media? should return false when media_urls is nil' do
    post = posts(:one)
    post.update(media_urls: nil)

    assert_not post.has_media?
  end

  test 'has_media? should return false when media_urls is empty array' do
    post = posts(:one)
    post.update(media_urls: [])

    assert_not post.has_media?
  end

  test 'duplicate? should return true when is_duplicate_of is present' do
    post = posts(:one)
    post.update(is_duplicate_of: posts(:two).id)

    assert post.duplicate?
  end

  test 'duplicate? should return false when is_duplicate_of is nil' do
    post = posts(:one)
    post.update(is_duplicate_of: nil)

    assert_not post.duplicate?
  end

  test 'classified? should return true when importance_score > 0' do
    post = posts(:one)
    post.update(importance_score: 50)

    assert post.classified?
  end

  test 'classified? should return false when importance_score = 0' do
    post = posts(:one)
    post.update(importance_score: 0)

    assert_not post.classified?
  end

  # Edge case tests
  test 'should handle nil values for optional fields' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      text: nil,
      media_urls: nil,
      is_important: nil,
      importance_score: 0,
      is_ad: nil,
      is_fluff: nil,
      is_duplicate_of: nil,
      topics: nil,
      classification_reasoning: nil,
      confidence: nil,
      classification_data: nil,
      classified_by_session_id: nil
    )
    assert post.valid?
  end

  test 'should handle empty text' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      text: ''
    )
    assert post.valid?
  end

  test 'should handle long text' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      text: 'A' * 10000
    )
    assert post.valid?
  end

  test 'should handle multiple media URLs' do
    post = posts(:one)
    post.media_urls = [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/video.mp4'
    ]
    assert post.save
    post.reload
    assert_equal 3, post.media_urls.length
  end

  test 'should handle multiple topics' do
    post = posts(:one)
    post.topics = [ 'ruby', 'rails', 'programming', 'web development' ]
    assert post.save
    post.reload
    assert_equal 4, post.topics.length
  end

  test 'should handle empty topics array' do
    post = posts(:one)
    post.topics = []
    assert post.save
    post.reload
    assert_equal [], post.topics
  end

  test 'should handle float importance_score' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      importance_score: 75.5
    )
    assert post.valid?
  end

  test 'should handle classification_data as jsonb' do
    post = posts(:one)
    post.classification_data = { model: 'gpt-4', tokens: 150, confidence: 0.95 }
    assert post.save
    post.reload
    assert_equal 'gpt-4', post.classification_data['model']
    assert_equal 150, post.classification_data['tokens']
  end

  test 'should handle nil classified_by_session' do
    post = Post.new(
      channel: channels(:one),
      telegram_message_id: 99999,
      published_at: Time.current,
      classified_by_session_id: nil
    )
    assert post.valid?
  end
end
