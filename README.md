# URSS - Ultimate Record Sh made Simple

URSS is a lightweight Bash wrapper to start synchronized ROS 2 bag recording and network packet capture (pcap) from one YAML preset.

It is designed for fast test-session logging where you want:
- one command to start recording,
- optional ROS bag + optional tcpdump,
- predictable output names and folders,
- clean stop on Ctrl+C.

## What It Does

URSS runs [record.sh](record.sh) with a preset YAML file.

From that preset it can:
- start `ros2 bag record` with optional topic list and extra args,
- start `tcpdump` in background (via `sudo`) with optional args,
- create output directories if missing,
- generate output names with timestamp and optional incremental IDs,
- stop both processes together when interrupted.

## Repository Layout

- [record.sh](record.sh): main launcher script.
- [record.yaml](record.yaml): default/general example preset.
- [qos_profiles.yaml](qos_profiles.yaml): QoS overrides example for ROS bag record.
- Presets for common stacks:
	- [full_stack.yaml](full_stack.yaml)
	- [full_stack_no_pcap.yaml](full_stack_no_pcap.yaml)
	- [full_stack_orin_only.yaml](full_stack_orin_only.yaml)
	- [perception.yaml](perception.yaml)
	- [fast_limo_only.yaml](fast_limo_only.yaml)
	- [pcap_only.yaml](pcap_only.yaml)

Output folders (default):
- [recordings/bag](recordings/bag)
- [recordings/pcap](recordings/pcap)

## Requirements

- Linux
- Bash
- ROS 2 with `ros2 bag` available in your shell
- `tcpdump` installed
- `sudo` privileges for packet capture

Optional but recommended:
- sourced ROS 2 environment before running URSS

## Quick Start

1. Make script executable (once):

```bash
chmod +x ./record.sh
```

2. Run with a preset:

```bash
./record.sh record.yaml
```

3. If `pcap: true`, URSS prints disk space and asks:

```text
Continue? [Y/N]:
```

4. Stop recording with Ctrl+C.

URSS will try to terminate both ROS bag and tcpdump cleanly.

## Typical Preset Usage

```bash
./record.sh full_stack.yaml
./record.sh full_stack_no_pcap.yaml
./record.sh perception.yaml
./record.sh pcap_only.yaml
```

## YAML Preset Reference

All keys are top-level fields.

### `pcap` (true/false)

- `true`: start tcpdump capture.
- `false`: do not start tcpdump.

### `bag` (true/false)

- `true`: start ROS 2 bag recording.
- `false`: do not start ROS bag.

### `bag_dir`

Directory for ROS bag output. Created automatically if missing.

### `pcap_dir`

Directory for pcap output. Created automatically if missing.

### `bag_args`

Extra arguments passed to `ros2 bag record`.

Important restrictions:
- Do not include `topics` here.
- Do not include `-o` here (use `bag_name` instead).

### `topics`

Space-separated topic list, for example:

```yaml
topics: /tf /tf_static /imu/data /lidar_points
```

Leave empty to let `bag_args` decide what to record.

### `pcap_args`

Extra arguments passed to `tcpdump`.

Restriction:
- Do not include `-w` here (use `pcap_name` instead).

### `pcap_name`

Base file name for pcap output (without path). If empty, no explicit `-w` is passed.

Supports `TIMESTAMP` placeholder.

Example:

```yaml
pcap_name: tcpdump_TIMESTAMP
```

### `bag_name`

Base directory name for rosbag output. If empty, no explicit `-o` is passed.

Supports `TIMESTAMP` placeholder.

Example:

```yaml
bag_name: rosbag_TIMESTAMP
```

### `date_format`

Date format used for `TIMESTAMP`, passed to `date`.

Example:

```yaml
date_format: "%Y_%m_%d-%H_%M_%S"
```

### `enable_ids` (true/false)

- `true`: append incremental suffix like `__1`, `__2`, ...
- `false`: no incremental suffix.

ID selection is shared across bag and pcap directories by taking the highest existing ID and incrementing it.

## Output Naming Behavior

Given:

```yaml
bag_dir: ./recordings/bag
pcap_dir: ./recordings/pcap
bag_name: rosbag_TIMESTAMP
pcap_name: tcpdump_TIMESTAMP
enable_ids: true
```

You may get outputs like:
- `./recordings/bag/rosbag_2026_04_17-14_20_33__7`
- `./recordings/pcap/tcpdump_2026_04_17-14_20_33__7.pcap`

## Included Presets

- [full_stack.yaml](full_stack.yaml): bag + pcap, full stack topics.
- [full_stack_no_pcap.yaml](full_stack_no_pcap.yaml): bag only, full stack topics.
- [full_stack_orin_only.yaml](full_stack_orin_only.yaml): bag + pcap, ORIN-focused stack.
- [perception.yaml](perception.yaml): bag + pcap for perception-related topics.
- [fast_limo_only.yaml](fast_limo_only.yaml): bag only for fast_limo topics.
- [pcap_only.yaml](pcap_only.yaml): pcap only.
- [record.yaml](record.yaml): minimal general-purpose example.

## Logs

URSS redirects process output to log files near the recording outputs:
- bag log: `<bag_output_path>.log`
- pcap log: `<pcap_output_path>.log`

Use these logs when startup fails due to invalid args or environment issues.

## Common Issues

### "wrong number of arguments"

URSS requires exactly one argument (a preset file):

```bash
./record.sh record.yaml
```

### "file named '...' not found"

Check the preset path and run from the repository root, or pass an absolute/relative path that exists.

### tcpdump does not start

- Ensure `pcap: true`.
- Confirm `tcpdump` is installed.
- Confirm you accepted the `Continue? [Y/N]` prompt.
- Check the generated pcap `.log` file for argument errors.

### ros2 bag does not start

- Ensure `bag: true`.
- Verify ROS 2 is sourced and `ros2` is available.
- Check the generated bag `.log` file for bad `bag_args` or QoS path issues.

## Notes

- URSS currently parses simple top-level `key: value` YAML entries.
- Keep presets flat and avoid duplicated keys.
- Comments are supported, but keep values on a single line.
