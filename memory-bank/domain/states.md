---
title: No Fluff Domain States
doc_kind: domain
doc_function: canonical
purpose: Current follower authorization, channel access, assignment and subscription states with evidence and gaps.
derived_from:
  - ../dna/governance.md
  - model.md
  - rules.md
status: active
audience: humans_and_agents
canonical_for:
  - domain_states
  - state_transitions
---

# Domain States

## State machines

| State machine | Concept | Runtime owner | Notes |
| --- | --- | --- | --- |
| `SM-01 Follower authorization` | Follower user | `FollowerUser.auth_status` | Exact transition authorization is spread across service/model; owner review needed |
| `SM-02 MTProto channel access` | Channel | `Channel.user_access_status` | Current acquisition path |
| `SM-03 Follower assignment` | Channel | `Channel.assignment_status` | Current channel-to-follower assignment state |
| `SM-04 Channel subscription` | Subscription | `Subscription.active` | Boolean active/inactive relation |
| `SM-05 Legacy Bot API join` | Channel | `bot_join_status` state machine | Compatibility state; not current production acquisition owner |

## States

| State machine | States | Meaning / evidence |
| --- | --- | --- |
| `SM-01` | `pending`, `authorized`, `failed`, `banned`, `revoked` | Declared by [FollowerUser](../../app/models/follower_user.rb); only `authorized` with a persisted session is recurring-sync eligible |
| `SM-02` | `not_joined`, `joining`, `joined`, `join_failed`, `left`, `access_lost` | Declared by [Channel](../../app/models/channel.rb); current sync proceeds through resolved/joined MTProto access |
| `SM-03` | `unassigned`, `assigned`, `reassigning`, `assignment_failed` | Declared by [Channel](../../app/models/channel.rb) |
| `SM-04` | `active`, `inactive` | Active subscriptions participate in recurring sync and delivery selection |
| `SM-05` | `not_joined`, `joining`, `joined`, `join_failed` | Retained legacy/compatibility state in `Channel` |

## Confirmed transitions

| Transition ID | From | To | Trigger / precondition | Source |
| --- | --- | --- | --- | --- |
| `TR-01` | `SM-02 not_joined/join_failed` | `joining` then `joined` | Authorized follower resolves and successfully joins a public channel | [Sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| `TR-02` | `SM-02 joining/not_joined` | `join_failed` | MTProto join fails | [Sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| `TR-03` | `SM-04 inactive` | `active` | User re-adds an existing inactive subscription | [Channel service](../../app/services/telegram/channel_service.rb) |
| `TR-04` | `SM-04 active` | removed/inactive path | User removes/deactivates follow relation | Existing command/service paths; exact delete-vs-deactivate behavior depends on entrypoint |

## Gaps

- `SI-01` Full allowed transition matrix for follower authorization and
  assignment is not centralized in existing docs; do not invent it.
- `SI-02` `Post` classification uses persisted fields rather than an explicit
  state enum; no separate domain state machine is asserted.
- `SI-03` A missing `Delivery` means «no recorded success», not necessarily
  «never attempted».
