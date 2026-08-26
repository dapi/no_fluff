# Live MTProto channel vertical slice

## Status: prepared, not production-proven

The application-owned pilot path is `Channels::MtprotoChannelSyncJob`. It restores the encrypted `FollowerUser` StringSession for each Telethon request, uses the configured SOCKS5 proxy, resolves and joins a public channel, imports a bounded cursor-based batch, and queues `Content::ProcessPostJob` for new posts only.

`Content::ProcessPostJob` performs the configured LLM classification and only queues `Content::DeliverPostsJob` when that result is deliverable. The sync path never calls the Bot API to join a channel and tests never contact Telegram or send a message.

This commit is not evidence of a live join, read, classification, or delivery. Production evidence must be collected separately by running one approved public pilot channel after deployment.

Safe pilot invocation (replace only the public username):

```ruby
channel = Channel.find_by!(username: "PUBLIC_USERNAME")
Channels::MtprotoChannelSyncJob.perform_later(channel.id, FollowerUser.authorized.find_by!(phone_number: ENV.fetch("NO_FLUFF_PILOT_FOLLOWER_PHONE")).id, 20)
```
