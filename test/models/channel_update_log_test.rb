require "test_helper"

class ChannelUpdateLogTest < ActiveSupport::TestCase
  test "should create and save channel update log" do
    log = ChannelUpdateLog.new(
      source: 'FetchPostsJob',
      message: 'Successfully processed 15 posts',
      status: 'success',
      job_id: 'abc123',
      execution_time_ms: 1250,
      data: { posts_processed: 15, new_posts: 3 }
    )

    assert log.save
    assert_equal 'FetchPostsJob', log.source
    assert_equal 'success', log.status.to_s
    assert_equal 15, log.data['posts_processed']
  end
end
