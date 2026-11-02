# Night operations

Runs a pipeline over many nights, one makeflow (or more) per night: staging each night's raw data from the
librarian, building and running its makeflow, waiting for you to review it, then pruning it and archiving it to cold
storage. The manager can start each of those steps by itself, within limits on how many nights are in flight at once,
and stops at review.

Nothing here is specific to one pipeline. Each pipeline that uses it keeps an `operations/` folder of its own beside
its toml, with a `config.toml` that lists its steps, and the step scripts that are its own. The first is
[Phase II IDR1 v1's](../pipelines/phase_II/idr1/v1/operations/).

There are two layers:

- **Step scripts**: one bash script per step, each doing one step for one night. They hold all of the decisions
  about data (what to stage, what to delete, what goes to cold storage) and can be read, edited, and run by hand.
  Most are the pipeline's own; `scripts/run.sh` (run a makeflow, or resume it) and `scripts/archive.sh` (copy to
  cold storage) are the same for every pipeline.
- **`manager.py` / `tui.py`**: works out where each night is from the files the steps leave behind, starts the
  next step for each night in its own detached `screen`, and shows it all. It never touches data itself, and keeps
  no state of its own beyond files, so quitting or restarting it never affects a running night.

## Running it

Steps must run on the host that `makeflow_nrao.sh` runs on (`herapost-master` at NRAO), so the manager runs there
too, with the pipeline's conda environment active (it needs `textual` for the TUI):

```bash
ssh herapost-master
screen -S p2_manager
conda activate phase_II_idr1
cd /lustre/aoc/projects/hera/phase-II-analysis/idr1/src/hera_pipelines
python operations/tui.py --config pipelines/phase_II/idr1/v1/operations/config.toml
```

Then detach with `Ctrl-A d`, and come back later with `screen -r p2_manager`. Inside screen the TUI is
keyboard-only: screen garbles mouse clicks, which would crash it. Auto mode starts off; press `space` to turn it on. The nights to process are in `nights.txt` beside the config, one JD per line, started in that order
(or add them with `n`).

## What's recorded where

Every step runs through `scripts/step.sh`, which records how it went in `{state_root}/{JD}/`:

- `{step}.started`: when it started, on which host, as which process
- `{step}.exit`: its exit code and when it finished (missing while it runs)
- `logs/{step}.log`: everything it printed, added to on every rerun

`step.sh` refuses to run a step until every step before it has succeeded, or, for a step after review, until the
night has been approved; a refusal is recorded as the step failing, with the reason in its log. The manager adds
`{step}.launched` when it starts a screen, `approved` (who, when, and your note), and `hold`. `ls` a night's folder
there to see exactly what has happened. `{state_root}/auto_mode` holds auto mode's setting, and
`{state_root}/manager.lock` stops a second manager from launching anything as well.

Each step runs in a screen named `{prefix}_{step}_{JD}`. When a step succeeds, its screen closes. When one fails,
its screen stays open at a shell in the relevant folder, so you can attach and look around.

## Keys

| key | |
|---|---|
| `space` | auto mode on/off |
| `s` | start the selected night's next step, or retry the one that failed (for a makeflow, it asks for the job cap), if its limit has room: like the scheduler, it never starts more than `[limits]` allows |
| `a` | attach to the night's screen (`Ctrl-A d` to come back, or `Ctrl-A a d` when the TUI is itself in a screen; from another terminal, `screen -d <its name>` does it too) |
| `l` / `e` | read the current step's log / the failed makeflow jobs' logs (`:n` for the next one in `less`) |
| `p` | hera_opm's `pipeline_status.py` report, for the night's makeflow |
| `y` / `h` | approve the night (its steps after review then run) / hold it, so auto mode leaves it alone (again to release) |
| `n` | add nights to the queue |
| `x` | Ctrl-C the running step. For a makeflow, that aborts its jobs |
| `R` | reset: forget a step and the ones after it, so they run again. Only markers are removed, never data |
| `q` | quit (everything running keeps running) |

## When things go wrong

- **A makeflow failed** ("run failed"): `e` shows the failed jobs' logs, `a` attaches to its screen. Fix what's
  wrong, exit that screen, and press `s` to resume the makeflow. Only the failed jobs, and those after them, rerun.
  The last attempt's error logs are kept in `previous_errors/attempt_N/` in the makeflow folder.
- **A step is "lost"**: it started but its screen is gone (a reboot, or a killed screen). Look at its log (`l`),
  then `s` to run it again.
- **A night isn't worth finishing**: hold it (`h`) so auto mode leaves it alone, and clean it up by hand.

## Without the TUI

The same things are available from the command line, in case you'd rather script them (`$OPS_CONFIG` can stand in
for `--config`):

```bash
python operations/manager.py --config CONFIG status
python operations/manager.py --config CONFIG tick --dry-run        # what auto mode would launch now
python operations/manager.py --config CONFIG launch run 2459861 --max-jobs 100
python operations/manager.py --config CONFIG approve 2459861 --note "looks fine"
python operations/manager.py --help                                # and the rest
```

A step can also be run in the foreground with `OPS_CONFIG=CONFIG bash operations/scripts/step.sh prune 2459861`.
A pipeline's own step scripts can even be run directly (`bash .../operations/prune.sh 2459861 <toml>`, which finds
the `config.toml` beside it), but then nothing is recorded, and nothing checks that the steps before it are done.

## Setting a pipeline up

Make an `operations/` folder beside the pipeline's toml, holding:

- **`config.toml`**, as in Phase II's:
  - `[paths]`: where each night's folders go (`nights_root`, `makeflow_root`, `raw_root`, `cold_root`,
    `state_root`), relative to the config. Nothing launches while any is still `FILL_ME_IN`.
  - `[workflow] steps`: the night's steps, in order, with `"review"` where each night should wait for you, and
    `toml`: the pipeline toml every step is given (a step can name its own).
  - `[steps.<step>]`, for steps that need any of: `script` (the default is `<step>.sh` beside the config, or else
    the shared one in `scripts/`), `toml`, `makeflow = true` (it runs its toml's makeflow, so the manager shows its
    progress and asks for a job cap), and `limit` (an entry in `[limits]` capping how many nights may be in this
    step, and any other step with the same limit, at once).
  - `[limits]`: `max_in_flight` (nights started but not yet done) and `min_free_tb` (free space on `nights_root`
    below which no new night starts), optionally `cold_min_free_tb` (archive fails, copying nothing, unless
    `cold_root` would still have this much free after the night's copy), plus the limits the steps name.
  - `[makeflow] max_jobs`, and `[manager]`: `name`, `poll_seconds`, `session_prefix`, `required_host`, `email`.
  - Any sections of the pipeline's own, which its scripts read with `cfg <section> <key>`.
- **`nights.txt`**: the queue.
- **the step scripts that are its own**, each run as `bash <script> <JD> [<toml>]`. Each starts with
  `source "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/operations/scripts/common.sh" "$1"`, which reads
  the config and sets `NIGHT_DIR`, `MAKEFLOW_DIR`, `RAW_DIR`, `COLD_DIR`, and the rest, and defines helpers:
  `die`, `cfg`, `require_approved`, `delete_matching`, `delete_bundled`, `pack`, and `pack_makeflow_folder`.
  See `scripts/common.sh`.

A pipeline with two makeflows a night, as H6C has, lists two build and run pairs (`build`, `run`,
`build_post_inpaint`, `run_post_inpaint`), each with its own `toml`, and both runs with the same `limit`.

## Testing

`pytest operations/tests` runs the manager's own tests, on a toy pipeline (`tests/example_pipeline/`) and fake
stand-ins for the librarian, hera_opm's scripts, and mail (`tests/fake_bin/`). That includes nights going all the
way from staging to archived through the shared scripts. A pipeline's own tests (as in
`pipelines/phase_II/idr1/v1/operations/tests/`) use the same fakes, through `tests/support.py`.

`bash operations/tests/demo.sh` starts the TUI on four fake nights of the toy pipeline, so you can try it out with
real screens and no real data. `--pipeline pipelines/phase_II/idr1/v1/operations` runs Phase II's own steps instead.
