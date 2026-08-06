# Spectator, Replay, and Reporting

## Spectator

Eligibility derives from server match statistics. Team modes return living teammates; Deathmatch may return any living opponent. The client cycles only the allowlist, disables gameplay input, follows a Humanoid with an occluded camera, and restores BLIKK camera/input on respawn. There is no free-fly camera.

## Replay V1

The server records primitive snapshots at 5 Hz into a 30-second rolling buffer. Event logs cap at 512 entries. Death clips retain a 10-second pre-event window, cap at 30 clips, and cannot exceed 48,000 serialized bytes. Authorized clients request clips no faster than once every two seconds.

The current client is a developer clip-list/timeline inspector, not a complete ViewportFrame ghost player. Replay data never enters live Workspace.

## Reporting

BLIKKReportsV1 schema 1 stores reason, filtered optional note (160 characters), match identity, and bounded server-confirmed statistics. Limits are three reports per match, five per 30 minutes, and one reporter/target/match report. Records exclude chat, raw text, profiles, reserved codes, and automatic punishment.

