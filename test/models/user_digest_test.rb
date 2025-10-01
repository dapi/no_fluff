require "test_helper"

class UserDigestTest < ActiveSupport::TestCase
  # Fixture tests
  test "should load fixture" do
    user_digest = user_digests(:one)
    assert_not_nil user_digest
  end

  test "loaded fixture should be valid" do
    user_digest = user_digests(:one)
    assert user_digest.valid?
  end

  # Association tests
  test "should have telegram_user association" do
    user_digest = user_digests(:one)
    assert_not_nil user_digest.telegram_user
    assert_instance_of TelegramUser, user_digest.telegram_user
  end

  test "should belong to telegram_user" do
    user_digest = user_digests(:one)
    assert_respond_to user_digest, :telegram_user
  end

  test "should have many user_digest_items" do
    user_digest = user_digests(:one)
    assert_respond_to user_digest, :user_digest_items
  end

  test "should have many posts through user_digest_items" do
    user_digest = user_digests(:one)
    assert_respond_to user_digest, :posts
  end

  test "should destroy associated user_digest_items when destroyed" do
    user_digest = user_digests(:one)
    assert_difference 'UserDigestItem.count', -1 do
      user_digest.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 10,
      posts_included_count: 5
    )
    assert digest.valid?
  end

  test "should require telegram_user" do
    digest = UserDigest.new(
      posts_analyzed_count: 10,
      posts_included_count: 5
    )
    assert_not digest.valid?
    assert digest.errors[:telegram_user].present?
  end

  test "should require posts_analyzed_count to be greater than or equal to 0" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: -1,
      posts_included_count: 0
    )
    assert_not digest.valid?
    assert digest.errors[:posts_analyzed_count].present?
  end

  test "should accept posts_analyzed_count of 0" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 0,
      posts_included_count: 0
    )
    assert digest.valid?
  end

  test "should require posts_included_count to be greater than or equal to 0" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 10,
      posts_included_count: -1
    )
    assert_not digest.valid?
    assert digest.errors[:posts_included_count].present?
  end

  test "should accept posts_included_count of 0" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 10,
      posts_included_count: 0
    )
    assert digest.valid?
  end

  # Enum tests
  test "should have status enum" do
    digest = user_digests(:one)
    assert_respond_to digest, :status
    assert_respond_to digest, :status_pending?
    assert_respond_to digest, :status_building?
    assert_respond_to digest, :status_ready?
    assert_respond_to digest, :status_sending?
    assert_respond_to digest, :status_sent?
    assert_respond_to digest, :status_failed?
  end

  test "should set status enum values" do
    digest = user_digests(:one)

    digest.status = :pending
    assert digest.status_pending?
    assert_equal "pending", digest.status

    digest.status = :building
    assert digest.status_building?
    assert_equal "building", digest.status

    digest.status = :ready
    assert digest.status_ready?
    assert_equal "ready", digest.status

    digest.status = :sending
    assert digest.status_sending?
    assert_equal "sending", digest.status

    digest.status = :sent
    assert digest.status_sent?
    assert_equal "sent", digest.status

    digest.status = :failed
    assert digest.status_failed?
    assert_equal "failed", digest.status
  end

  # Scope tests
  test "pending scope should return only pending digests" do
    digest = user_digests(:one)
    digest.update(status: :pending)

    pending_digests = UserDigest.pending
    assert_includes pending_digests, digest
  end

  test "pending scope should not return non-pending digests" do
    digest = user_digests(:one)
    digest.update(status: :sent)

    pending_digests = UserDigest.pending
    assert_not_includes pending_digests, digest
  end

  test "building scope should return only building digests" do
    digest = user_digests(:one)
    digest.update(status: :building)

    building_digests = UserDigest.building
    assert_includes building_digests, digest
  end

  test "ready scope should return only ready digests" do
    digest = user_digests(:one)
    digest.update(status: :ready)

    ready_digests = UserDigest.ready
    assert_includes ready_digests, digest
  end

  test "sent scope should return only sent digests" do
    digest = user_digests(:one)
    digest.update(status: :sent)

    sent_digests = UserDigest.sent
    assert_includes sent_digests, digest
  end

  test "failed scope should return only failed digests" do
    digest = user_digests(:one)
    digest.update(status: :failed)

    failed_digests = UserDigest.failed
    assert_includes failed_digests, digest
  end

  test "scheduled_for_now scope should return digests scheduled for now or past" do
    digest = user_digests(:one)
    digest.update(scheduled_for: 1.hour.ago)

    scheduled_digests = UserDigest.scheduled_for_now
    assert_includes scheduled_digests, digest
  end

  test "scheduled_for_now scope should not return future scheduled digests" do
    digest = user_digests(:one)
    digest.update(scheduled_for: 1.hour.from_now)

    scheduled_digests = UserDigest.scheduled_for_now
    assert_not_includes scheduled_digests, digest
  end

  test "for_user scope should return digests for specific user" do
    user = telegram_users(:one)
    digest = user_digests(:one)

    user_digests_result = UserDigest.for_user(user)
    assert_includes user_digests_result, digest
  end

  test "for_user scope should not return digests for other users" do
    user1 = telegram_users(:one)
    digest2 = user_digests(:two)

    user1_digests = UserDigest.for_user(user1)
    assert_not_includes user1_digests, digest2
  end

  test "recent scope should return digests created in last 30 days" do
    digest = user_digests(:one)
    digest.update(created_at: 15.days.ago)

    recent_digests = UserDigest.recent
    assert_includes recent_digests, digest
  end

  test "recent scope should not return digests created more than 30 days ago" do
    digest = user_digests(:one)
    digest.update(created_at: 31.days.ago)

    recent_digests = UserDigest.recent
    assert_not_includes recent_digests, digest
  end

  # Method tests
  test "mark_as_building! should set status to building" do
    digest = user_digests(:one)
    digest.update(status: :pending)

    digest.mark_as_building!
    digest.reload
    assert digest.status_building?
  end

  test "mark_as_ready! should set status to ready" do
    digest = user_digests(:one)
    digest.update(status: :building)

    digest.mark_as_ready!
    digest.reload
    assert digest.status_ready?
  end

  test "mark_as_sending! should set status to sending" do
    digest = user_digests(:one)
    digest.update(status: :ready)

    digest.mark_as_sending!
    digest.reload
    assert digest.status_sending?
  end

  test "mark_as_sent! should set status to sent and update sent_at" do
    digest = user_digests(:one)
    digest.update(status: :sending, sent_at: nil)

    freeze_time do
      digest.mark_as_sent!
      digest.reload
      assert digest.status_sent?
      assert_not_nil digest.sent_at
      assert_in_delta Time.current, digest.sent_at, 1.second
    end
  end

  test "mark_as_failed! should set status to failed and store error message" do
    digest = user_digests(:one)
    digest.update(status: :sending)

    error_message = "Failed to send digest"
    digest.mark_as_failed!(error_message)
    digest.reload
    assert digest.status_failed?
    assert_equal error_message, digest.error_message
  end

  test "has_posts? should return true when posts_included_count > 0" do
    digest = user_digests(:one)
    digest.update(posts_included_count: 5)

    assert digest.has_posts?
  end

  test "has_posts? should return false when posts_included_count = 0" do
    digest = user_digests(:one)
    digest.update(posts_included_count: 0)

    assert_not digest.has_posts?
  end

  # Edge case tests
  test "should handle nil values for optional fields" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 0,
      posts_included_count: 0,
      status: :pending,
      scheduled_for: nil,
      sent_at: nil,
      content: nil,
      format_settings: nil,
      telegram_message_id: nil,
      error_message: nil
    )
    assert digest.valid?
  end

  test "should handle format_settings as jsonb" do
    digest = user_digests(:one)
    digest.format_settings = { theme: "dark", font_size: 14, show_images: true }
    assert digest.save
    digest.reload
    assert_equal "dark", digest.format_settings["theme"]
    assert_equal 14, digest.format_settings["font_size"]
    assert_equal true, digest.format_settings["show_images"]
  end

  test "should handle empty format_settings hash" do
    digest = user_digests(:one)
    digest.format_settings = {}
    assert digest.save
    digest.reload
    assert_equal({}, digest.format_settings)
  end

  test "should handle long content" do
    digest = user_digests(:one)
    digest.content = "A" * 50000
    assert digest.save
    digest.reload
    assert_equal 50000, digest.content.length
  end

  test "should handle large posts_analyzed_count" do
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 1000,
      posts_included_count: 50
    )
    assert digest.valid?
  end

  test "should allow posts_included_count to be greater than posts_analyzed_count" do
    # This might be an edge case but the validation doesn't prevent it
    digest = UserDigest.new(
      telegram_user: telegram_users(:one),
      posts_analyzed_count: 10,
      posts_included_count: 20
    )
    assert digest.valid?
  end

  test "should handle status transitions" do
    digest = user_digests(:one)

    digest.mark_as_building!
    assert digest.status_building?

    digest.mark_as_ready!
    assert digest.status_ready?

    digest.mark_as_sending!
    assert digest.status_sending?

    digest.mark_as_sent!
    assert digest.status_sent?
  end

  test "should handle failed status from any state" do
    digest = user_digests(:one)

    digest.update(status: :building)
    digest.mark_as_failed!("Build failed")
    assert digest.status_failed?
    assert_equal "Build failed", digest.error_message

    digest.update(status: :sending)
    digest.mark_as_failed!("Send failed")
    assert digest.status_failed?
    assert_equal "Send failed", digest.error_message
  end
end
