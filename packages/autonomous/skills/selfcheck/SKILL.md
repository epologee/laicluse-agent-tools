---
name: selfcheck
description: Self-pacing heartbeat for a persistent process that can schedule its own wake-ups but has no cron. Keeps a bg/continuous rover alive by re-entering on an interval, re-engaging a quietly-ended turn, beating the host stall timer with a progress tick, and reaching a terminal verdict when the work is truly done or blocked. Loaded by keepalive when the runtime exposes a wake-up hook but no cron.
user-invocable: false
effort: low
---

# Autonomy Self-Check

The heartbeat for a persistent process that has no cron but can schedule its own wake-ups.

`cron` keeps an interactive session alive between idle turns. `selfcheck` does the same job for the other runtime that needs it: a persistent or continuous process (a conveyor line, a detached run) that the host supervises but does not pause between turns the way a REPL does. Such a process was assumed to drive straight to completion in one unbroken run, but that is false for a rover: it can **end a turn without re-driving the next one** (the goal mechanism does not always re-fire when a turn closes), go silent, and get killed by a host that watches for stalls. The gap this skill covers is exactly that one between turns; the wake-up fires on idle and re-drives a quietly-dropped turn. (One unbroken turn that never yields is out of scope; see "The boundary".)

`keepalive` routes here only after its probe finds a **self-pacing wake-up hook** but no cron (see `keepalive` for the probe). The mechanism is whatever such hook the runtime exposes; in a Claude `claude --bg` harness it is the `ScheduleWakeup` tool. The skill is written against the abstract shape — schedule a re-entry after N seconds, carrying a prompt that fires when the process next goes idle — with `ScheduleWakeup` as the concrete Claude instance, the same way `cron` and `keepalive` name `CronCreate`/`CronList`; a future agent may expose a differently-named hook of the same shape.

## No wakeup, no-op

This skill acts only when there is a real self-pacing hook to act on. It is a no-op whenever the runtime exposes neither a cron nor a wake-up hook: a pure batch process that genuinely runs to completion in one pass needs no heartbeat and gets none. `keepalive` owns the probe that decides this; a caller never branches on the mode itself.

## The interval

```
SELFCHECK_INTERVAL_SECONDS = 270   # 4.5 minutes
```

The constraint that fixes this number is one inequality: `interval < stall_window − longest_expected_turn`. Because the wake-up fires on idle, the real gap between two beats is the interval plus however long the turn in flight when it fires runs before yielding; that sum must stay under the host's stall window. With the conveyor's 10-minute window, 270s leaves the interval itself 5.5 minutes of headroom and still clears the window after a four-minute turn (≈8.5 minutes total). A turn that by itself approaches `window − interval` is the regime the boundary section calls out, not a margin this constant can widen.

The value lands on 270 rather than 300 for a secondary reason that only some runtimes have: a prompt cache with a short TTL. A re-entry inside the TTL reads cached context instead of paying a full miss; the Claude harness's `ScheduleWakeup` guidance documents a 5-minute TTL and flags 300s as the worst case, so 270s stays just inside it. Where a runtime caches differently or not at all, this drops away and the inequality alone still picks a sub-window interval.

The constant is tied to the host's stall window, so it must be revisited if that window changes. For the conveyor the window is `STALL_TIMEOUT_MS` in `laicluse-agent-workbench`, `packages/conveyor/skills/start/bin/conveyor-start.mjs`; a maintainer changing it there should grep `SELFCHECK_INTERVAL_SECONDS` here, since nothing enforces the link automatically. Deriving the interval from that value across the repo boundary, or tuning it per-order, are deliberate non-goals here.

## Setup (first wake-up)

`keepalive` calls this skill when its probe finds a persistent process with a wake-up hook, passing the loop-file path as the skill argument (the same way `cron` receives its caller's path). Your job:

1. Schedule the first self-check wake-up via the runtime's hook (`ScheduleWakeup` in the Claude harness) at `SELFCHECK_INTERVAL_SECONDS`, carrying the standard self-check prompt below with `<FILENAME>` filled in.
2. Return the sentinel `none (self-check heartbeat)` to the caller so it writes that value into the loop file's `cron_job_id`. The value is one of the canonical markers defined in `autonomous:keepalive` ("The return contract"); that section is the single owner of the marker vocabulary. The field name stays `cron_job_id` across all runtime modes for one uniform marker; here there is no live cron, the marker just records that a wake-up heartbeat is active.

The loop file does not have to exist yet at the moment of the first schedule; a wake-up that fires before the file lands does nothing that tick and the next one retries, exactly as cron's setup does.

### Standard self-check prompt

```
Self-check heartbeat. Read the file `.autonomous/<FILENAME>.md` in this
project. If it does not exist yet, the main run is still finishing setup;
do nothing this tick. Otherwise run one self-check. Acquire the loop-file
lock first (the same lock `cron` and `wake` use, see autonomous:cron's
concurrency section) so two fires cannot act at once; release it at the end.

1. Run `date +%H:%M` first; never guess the time. Read the Phase, the
   `cron_job_id`, and the tail of the Log.

2. STAND DOWN unless this is still the active self-check heartbeat. If
   `cron_job_id` is anything other than `none (self-check heartbeat)` — a
   live cron id (a `wake` re-decided this run as interactive), or `stopped`,
   `paused`, `failed` (the run was cut) — this wake-up is a leftover, not the
   live heartbeat. Write one beat noting the marker, do NOT re-engage, do NOT
   reschedule. Stop here.

3. FIRST FIRE: if the Log holds no earlier `self-check:` beat, this is the
   first fire. Write one beat (`[HH:MM] self-check: first beat, Phase <X>`)
   and reschedule. Do not classify or re-engage on the first fire; you have
   no prior beat to measure progress against yet.

4. Otherwise classify, measuring against the PREVIOUS `self-check:` beat.
   Your own beats are never progress: a `self-check:` Log line does not
   count. Real progress is a Phase change or any non-beat Log entry dated
   after the previous beat.
   - PROGRESSING: there is real progress since the previous beat. The run is
     driving itself. Write a beat
     (`[HH:MM] self-check: progressing, Phase <X>`) and reschedule.
   - WAITING: no real progress, AND the latest non-beat Log entry names an
     external arrival channel that will re-enter THIS run on its own — a bg
     task that will notify, or an operator message. (A cron is not such a
     channel: this run has no cron, so "waiting on a cron tick" is a STALL,
     not a WAIT.) Write a beat naming what it waits on and reschedule. Do NOT
     re-engage; double-driving a parked mission is wrong.
   - STALLED: anything else — no real progress and no qualifying wait. When
     in doubt between WAITING and STALLED, choose STALLED: a redundant
     re-drive is cheap, a missed one is the silent death this exists to stop.
     Re-engage: follow the `## Instructions` section of THIS loop file for
     the current Phase and do its next action, write a beat
     (`[HH:MM] self-check: re-engaged <Phase>, <what you did>`), then
     reschedule.

5. If the run is genuinely finished or genuinely blocked with no path
   forward, do not reschedule: reach a terminal verdict by invoking
   `rover:stop` with this loop file's path as the argument
   (`.autonomous/<FILENAME>.md`) — passing the path matters, with no argument
   `stop` asks an operator which file to stop and none is present. If `stop`
   instead bounces the run back to DRIVE (it found unresolved work), the run
   was not finished after all: treat that as a re-engage and reschedule
   rather than calling `stop` again. Ending the heartbeat is simply not
   scheduling another wake-up.

To reschedule (steps 3 and 4): schedule the next wake-up at the heartbeat
interval, carrying THIS SAME prompt with `<FILENAME>` already substituted,
so the next fire is identical to this one.

Every fire writes one timestamped Log line (a "beat"; the "heartbeat" is
the recurring wake-up itself). That loop-file write is how the host detects
the run is still alive — it resets the host's stall timer — so a fire that
writes nothing, even one that decided there was nothing to do, looks dead
to the host and defeats the purpose.
```

Replace `<FILENAME>` (the bare loop-file stem, e.g. `BUILD-AUTH-PAGE`, not
the path or the `.md`) everywhere it appears — the read path, the step-5
`stop` argument — before scheduling the first wake-up; every later
reschedule carries that already-substituted prompt forward unchanged. The
prompt is frozen at first schedule: a later edit to this skill does not
reach an in-flight run, which carries the version that started it.

## Teardown

There is no cron to delete. The heartbeat ends by **not scheduling the next wake-up**. `stop` reaches its terminal verdict and simply does not reschedule; the already-fired wake-up was the last one. A caller that reads `cron_job_id: none (self-check heartbeat)` and looks for a live cron to cut finds none, which is correct.

## The boundary

The wake-up fires on idle, so this skill covers only the gap *between* turns. A single unbroken turn that runs past the stall window while writing nothing to the loop file is out of scope: with no idle moment the wake-up cannot fire. In practice the work is chopped into turns that each touch the loop file, so the residual risk is one tool call (a subagent spawn, say) that blocks the full window in one shot; catching a run that is alive but quiet inside such a call is the host-side complement the mission names, not this skill's job. The same idle-fire limit applies to `cron`.
