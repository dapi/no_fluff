require "test_helper"

class UserDigestItemTest < ActiveSupport::TestCase
  # Fixture tests
  test "should load fixture" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item
  end

  test "loaded fixture should be valid" do
    user_digest_item = user_digest_items(:one)
    assert user_digest_item.valid?
  end

  # Association tests
  test "should have user_digest association" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item.user_digest
    assert_instance_of UserDigest, user_digest_item.user_digest
  end

  test "should have post association" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item.post
    assert_instance_of Post, user_digest_item.post
  end

  test "should belong to user_digest" do
    item = user_digest_items(:one)
    assert_respond_to item, :user_digest
  end

  test "should belong to post" do
    item = user_digest_items(:one)
    assert_respond_to item, :post
  end

  # Validation tests
  test "should be valid with valid attributes" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 2
    )
    assert item.valid?
  end

  test "should require user_digest" do
    item = UserDigestItem.new(
      post: posts(:one),
      position: 1
    )
    assert_not item.valid?
    assert item.errors[:user_digest].present?
  end

  test "should require post" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      position: 1
    )
    assert_not item.valid?
    assert item.errors[:post].present?
  end

  test "should require position" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: nil
    )
    assert_not item.valid?
    assert item.errors[:position].present?
  end

  test "should require position to be an integer" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 1.5
    )
    assert_not item.valid?
    assert item.errors[:position].present?
  end

  test "should require position to be greater than 0" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 0
    )
    assert_not item.valid?
    assert item.errors[:position].present?
  end

  test "should accept position of 1" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 1
    )
    assert item.valid?
  end

  test "should accept large position values" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 1000
    )
    assert item.valid?
  end

  test "should require unique post_id scoped to user_digest_id" do
    existing_item = user_digest_items(:one)
    item = UserDigestItem.new(
      user_digest: existing_item.user_digest,
      post: existing_item.post,
      position: 2
    )
    assert_not item.valid?
    assert item.errors[:post_id].present?
  end

  test "should allow same post in different digests" do
    post = posts(:one)
    digest1 = user_digests(:one)
    digest2 = user_digests(:two)

    item1 = user_digest_items(:one) # Already exists for digest1

    item2 = UserDigestItem.new(
      user_digest: digest2,
      post: post,
      position: 1
    )
    assert item2.valid?
  end

  test "should allow different posts in same digest" do
    digest = user_digests(:one)
    post1 = posts(:one)
    post2 = posts(:two)

    item1 = user_digest_items(:one) # Already exists

    item2 = UserDigestItem.new(
      user_digest: digest,
      post: post2,
      position: 2
    )
    assert item2.valid?
  end

  # Scope tests
  test "ordered scope should return items ordered by position ascending" do
    digest = user_digests(:one)

    item1 = user_digest_items(:one)
    item1.update(position: 3)

    item2 = UserDigestItem.create!(
      user_digest: digest,
      post: posts(:two),
      position: 1
    )

    ordered_items = digest.user_digest_items.ordered
    assert_equal 1, ordered_items.first.position
    assert_equal 3, ordered_items.last.position
  end

  test "for_digest scope should return items for specific digest" do
    digest = user_digests(:one)
    item = user_digest_items(:one)

    digest_items = UserDigestItem.for_digest(digest)
    assert_includes digest_items, item
  end

  test "for_digest scope should not return items for other digests" do
    digest1 = user_digests(:one)
    item2 = user_digest_items(:two)

    digest1_items = UserDigestItem.for_digest(digest1)
    assert_not_includes digest1_items, item2
  end

  test "original_content scope should return items with is_original_content true" do
    item = user_digest_items(:one)
    item.update(is_original_content: true)

    original_items = UserDigestItem.original_content
    assert_includes original_items, item
  end

  test "original_content scope should not return items with is_original_content false" do
    item = user_digest_items(:one)
    item.update(is_original_content: false)

    original_items = UserDigestItem.original_content
    assert_not_includes original_items, item
  end

  test "summarized scope should return items with is_original_content false" do
    item = user_digest_items(:one)
    item.update(is_original_content: false)

    summarized_items = UserDigestItem.summarized
    assert_includes summarized_items, item
  end

  test "summarized scope should not return items with is_original_content true" do
    item = user_digest_items(:one)
    item.update(is_original_content: true)

    summarized_items = UserDigestItem.summarized
    assert_not_includes summarized_items, item
  end

  # Edge case tests
  test "should handle nil values for optional fields" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 1,
      summary: nil,
      formatted_content: nil,
      is_original_content: nil
    )
    assert item.valid?
  end

  test "should handle empty summary" do
    item = user_digest_items(:one)
    item.summary = ""
    assert item.save
    item.reload
    assert_equal "", item.summary
  end

  test "should handle long summary" do
    item = user_digest_items(:one)
    item.summary = "A" * 5000
    assert item.save
    item.reload
    assert_equal 5000, item.summary.length
  end

  test "should handle empty formatted_content" do
    item = user_digest_items(:one)
    item.formatted_content = ""
    assert item.save
    item.reload
    assert_equal "", item.formatted_content
  end

  test "should handle long formatted_content" do
    item = user_digest_items(:one)
    item.formatted_content = "B" * 10000
    assert item.save
    item.reload
    assert_equal 10000, item.formatted_content.length
  end

  test "should handle position ordering with gaps" do
    digest = user_digests(:one)

    item1 = user_digest_items(:one)
    item1.update(position: 1)

    item2 = UserDigestItem.create!(
      user_digest: digest,
      post: posts(:two),
      position: 5
    )

    ordered_items = digest.user_digest_items.ordered
    assert_equal item1, ordered_items.first
    assert_equal item2, ordered_items.second
  end

  test "should handle boolean is_original_content values" do
    item = user_digest_items(:one)

    item.is_original_content = true
    assert item.save
    item.reload
    assert_equal true, item.is_original_content

    item.is_original_content = false
    assert item.save
    item.reload
    assert_equal false, item.is_original_content
  end

  test "should maintain relationship when user_digest has many items" do
    digest = user_digests(:one)

    initial_count = digest.user_digest_items.count

    UserDigestItem.create!(
      user_digest: digest,
      post: posts(:two),
      position: 2
    )

    assert_equal initial_count + 1, digest.user_digest_items.reload.count
  end

  test "should maintain relationship when post has many digest items" do
    post = posts(:one)

    initial_count = post.user_digest_items.count

    UserDigestItem.create!(
      user_digest: user_digests(:two),
      post: post,
      position: 1
    )

    assert_equal initial_count + 1, post.user_digest_items.reload.count
  end

  test "should allow same position in different digests" do
    # digest1 already has item with position 1 from fixtures
    digest2 = user_digests(:two)

    # Create new post for digest2
    channel = Channel.create!(
      telegram_id: "9999999997",
      username: "test_channel_item"
    )
    post = channel.posts.create!(
      telegram_message_id: 77777,
      published_at: Time.current
    )

    # Should allow same position in digest2
    item2 = UserDigestItem.new(
      user_digest: digest2,
      post: post,
      position: 1
    )
    assert item2.valid?
  end

  test "should handle nil is_original_content as false-like" do
    item = UserDigestItem.new(
      user_digest: user_digests(:one),
      post: posts(:two),
      position: 1,
      is_original_content: nil
    )
    assert item.valid?
    assert item.save
  end
end
