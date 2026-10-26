# One-minute Mac-to-Mac timing capture

Quit the existing sender and receiver apps before using the diagnostic builds.
These builds collect timing summaries only, without pixels, window titles, or
cursor coordinates. Normal launches leave diagnostics disabled.

1. On the receiving Mac, unpack `OpenAirDisplay-Diagnostic-Receiver.zip` and
   double-click **Start Receiver.command**. Keep the receiver open.
2. On the sending Mac, double-click **Start Sender.command** in the Sender
   folder. Its default target is `10.254.217.10`; edit the command if the IP changes.
The receiver panel now shows **Timing diagnostics: On/Off**. A diagnostic
sender also requests activation after connecting. Before collecting phases, the
script verifies that receiver timing windows actually arrive; it aborts early
if they do not.

3. Grant Screen Recording to OpenAirDisplay Dev if requested. Once video is
   visible, press Enter in Terminal.
4. Follow the spoken/printed phases: 20 seconds idle, 20 seconds moving the
   pointer continuously over the receiver display, 20 seconds continuously
   dragging a window. Do not change quality or transport mid-run.
5. The script opens a timestamped folder on the sender Desktop containing
   `report.txt`, `timings.log`, and `phases.txt`. Share those files for analysis.

The diagnostic receiver sends its timing windows over the existing control
connection. The sender logs both sides. If the report says RECEIVER TIMINGS
MISSING, check that the new receiver was launched using its command file.
A stock receiver can still stream but cannot supply the new measurements.

The package does not replace `/Applications` apps. Both apps keep their existing
Debug identities; their development code signatures are normalized before
packaging. Receiver binaries support Intel and Apple silicon. No remote Mac is
modified or restarted automatically.

## Measurement limits

Frame and cursor gaps also include deliberate idle periods; use `phases.txt` to
interpret them. Window P95 values are reported separately from a pooled P95.
Queue delays use each machine's local monotonic clock. The default
AVSampleBufferDisplayLayer performs decode and presentation internally: its
actual visible frame times are not measured by this experiment. A quick enqueue
call does not prove that decoder or screen presentation is smooth. No claim of
physical input-to-photon latency is made.

## From a source checkout

Build both Debug schemes after `xcodegen generate`. Then use:

```sh
./tools/diagnose.sh receiver
./tools/diagnose.sh sender 10.254.217.10
```

Run these on their respective Macs. Python 3 is required only on the sender.
