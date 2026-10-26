#!/usr/bin/env python3
"""Summarize opt-in local stage timings; never claims to measure photons."""
import json
import sys
from collections import defaultdict
from pathlib import Path


def summarize(log, start=0):
    rows = defaultdict(list)
    records = 0
    sender_udp = []
    for line in log.splitlines():
        if 'DIAG {' not in line:
            continue
        try:
            report = json.loads(line.split('DIAG ', 1)[1])
            if report.get('time', 0) < start:
                continue
            role = report['role']
            if role == 'sender' and 'udpConfirmed' in report:
                sender_udp.append(report['udpConfirmed'])
            for stage, sample in report['stages'].items():
                rows[role, stage].append(sample)
            records += 1
        except (ValueError, KeyError, TypeError):
            continue
    out = ['OpenAirDisplay timing report', '', f'Diagnostic windows: {records}',
           'Each window is about 2 seconds. P95 below is the worst window P95,',
           'not a pooled percentile. No screen content or coordinates are recorded.', '',
           'role / stage                      samples   worst P95 ms    max ms   >50 ms']
    for (role, stage), windows in sorted(rows.items()):
        out.append(f'{role + "/" + stage:34} {sum(w["n"] for w in windows):7d}'
                   f' {max(w["p95"] for w in windows):14.2f}'
                   f' {max(w["max"] for w in windows):9.2f}'
                   f' {sum(w["over50"] for w in windows):8d}')
    candidates = []
    labels = {
        'encodeMs': 'encoder callback delay',
        'sendCompletionMs': 'local TCP send processing delay (not remote delivery)',
        'mainQueueMs': 'main thread dispatch wait',
        'workerQueueMs': 'video queue dispatch wait',
        'encodeDeliveryQueueMs': 'encoder output waiting for sender queue',
        'cursorMainDispatchMs': 'cursor waiting for receiver main thread',
        'displayEnqueueCallMs': 'display-layer enqueue call blocking',
    }
    for (role, stage), windows in sorted(rows.items()):
        if stage in labels and max(w['max'] for w in windows) > 50:
            candidates.append(f'- {role}: {labels[stage]} exceeded 50 ms.')
    out += ['', 'Observed local delay candidates (50 ms screening threshold):']
    out += candidates or ['No measured local stage exceeded 50 ms. This does not rule out network or presentation stalls.']
    if sender_udp:
        out += ['', f'UDP cursor confirmed in {sum(sender_udp)}/{len(sender_udp)} sender windows.']
        if not any(sender_udp) and ('receiver', 'cursorUDPReceiveGapMs') in rows:
            out += ['UDP arrived at the receiver, but the sender never confirmed it in this run.',
                    'Investigate the UDP acknowledgement path; TCP cursor fallback remained active.']
    out += ['', 'Interpretation:',
            '- captureGapMs includes legitimate idle periods: assess it during continuous dragging.',
            '- encodeMs measures submission to encoder callback.',
            '- sendCompletionMs ends when Network.framework processes the send, not remote delivery.',
            '- mainQueueMs / workerQueueMs measure dispatch wait, sampled at 10 Hz.',
            '- cursorMainDispatchMs measures receiver cursor dispatch wait before layer updates.',
            '- videoReceiveGapMs measures decoded-payload submission cadence, not actual screen refresh.',
            '- displayEnqueueCallMs is only the display-layer API call; hardware decode/presentation',
            '  inside AVSampleBufferDisplayLayer remains unmeasured.',
            '- cursor gaps include pauses when the mouse is stationary; UDP arrival with no',
            '  "cursor channel confirmed" can indicate an acknowledgement problem.',
            '- These timings localize candidates; they do not prove a single root cause.']
    if not any(role == 'receiver' for role, _ in rows):
        out += ['', 'RECEIVER TIMINGS MISSING: run the diagnostic receiver build on the other Mac.',
                'The ordinary receiver still works, but cannot report the new stage timings.']
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    print(summarize(Path(sys.argv[1]).read_text(errors='replace'),
                    float(sys.argv[2]) if len(sys.argv) > 2 else 0), end='')
