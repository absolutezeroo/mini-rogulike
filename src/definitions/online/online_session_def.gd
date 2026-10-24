class_name OnlineSessionDef
extends Resource
## What every online service shares (data/online/online_session.tres, read by the OnlineSession
## autoload; docs/online.md "The shared session"): how a refused identity is tried again and how
## far the services' retries back off while there is no network. Each service keeps its own
## retry_seconds (its data); these numbers only shape the tries after the first.

## Seconds a refused identify (a bad or revoked key, a captive portal's page instead of Talo's
## answer) is remembered: every service asking meanwhile gets the same answer without a call,
## then the next one asks the server again.
@export_range(5, 3600) var refused_identity_seconds := 60.0
## A service's retry waits its retry_seconds, then twice that, and so on up to this many times
## retry_seconds (1: never longer). A success starts again from retry_seconds.
@export_range(1, 64) var max_backoff := 8.0
