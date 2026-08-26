# Live MTProto channel vertical slice

## Status: production-proven

The application-owned path is `Channels::MtprotoChannelSyncJob`. It restores the encrypted `FollowerUser` StringSession for each Telethon request, uses the configured SOCKS5 proxy, resolves and joins a public channel, imports a bounded cursor-based batch, and queues `Content::ProcessPostJob` for new posts only.

`Content::ProcessPostJob` performs the configured LLM classification and only queues `Content::DeliverPostsJob` when that result is deliverable. Imported MTProto posts are delivered as bot messages containing the source text and canonical `t.me/<channel>/<message>` link; the bot is not required to be a member of the source channel.

## Durable delivery and recurring synchronization

Successful bot delivery is persisted in the `deliveries` ledger with a
PostgreSQL-unique `(telegram_user_id, post_id)` pair. The delivery worker locks
the post before checking and recording the ledger, so concurrent attempts cannot
send the same user/post pair twice. A rejected Bot API response creates no
ledger record and uses the job retry policy.

`Channels::RecurringMtprotoChannelSyncJob` runs every five minutes in
production and development. It serializes recurring runs with Solid Queue,
selects only active subscribed public channels assigned to an authorized
follower with an encrypted session, and queues bounded channel syncs. The
existing channel lock and post unique index preserve sync idempotency.

The public `/add` path resolves and joins through the MTProto follower client;
the Bot API remains solely the polling transport and delivery interface.

## Production evidence — 2026-08-26

Pilot channel: `@problemhunt`. Test follower account: the authorized Kazakhstan development line recorded in the private telecom registry.

Verified on `goga-office`:

1. encrypted Telethon `StringSession` restored in a fresh process;
2. public channel resolved and joined through the configured SOCKS5 proxy;
3. five recent Telegram messages read and persisted;
4. a second sync imported zero duplicates (`5 → 5` posts);
5. all five posts received LLM classification;
6. one deliverable post was sent by `@bez_sheluhi_bot` with source link `https://t.me/problemhunt/210` (delivery message ID `371944`);
7. both web and worker pods were recreated; the session restored again and the post count remained unchanged.

## Safe invocation

```ruby
channel = Channel.find_by!(username: "PUBLIC_USERNAME")
Channels::MtprotoChannelSyncJob.perform_later(
  channel.id,
  FollowerUser.authorized.find_by!(phone_number: ENV.fetch("NO_FLUFF_PILOT_FOLLOWER_PHONE")).id,
  20
)
```

Do not treat this one pilot as evidence for pool scaling, private-channel access, or long-term rate-limit behavior. Those remain separate gates.

## Durable recurring delivery evidence — 2026-08-26

Production image `188ee98d6230eb08fd8f4fb201cb8b48fa823341` adds a database-unique `Delivery` ledger, five-minute recurring MTProto synchronization, and the MTProto-backed public-channel add path used by the bot. A live `@problemhunt` add returned the localized success response, queued and completed initial sync, then completed the scheduler-driven recurring sync. Post count and ledger count both remained five, proving that the repeated pass produced neither duplicate posts nor duplicate deliveries; ready and failed queues were empty afterward.
