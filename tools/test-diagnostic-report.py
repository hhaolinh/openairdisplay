import importlib.util
import json
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('report', Path(__file__).with_name('diagnostic-report.py'))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

class ReportTests(unittest.TestCase):
    def test_filters_old_run_and_flags_missing_receiver(self):
        sample = dict(n=20, p50=1, p95=4, max=80, over50=1)
        old = dict(time=1, role='receiver', stages={'mainQueueMs': sample})
        new = dict(time=10, role='sender', stages={'encodeMs': sample})
        log = '\n'.join('prefix DIAG ' + json.dumps(row) for row in (old, new))
        result = report.summarize(log + '\nDIAG {broken', start=5)
        self.assertIn('Diagnostic windows: 1', result)
        self.assertIn('sender/encodeMs', result)
        self.assertIn('RECEIVER TIMINGS MISSING', result)
        self.assertNotIn('receiver/mainQueueMs', result)

    def test_window_percentiles_are_not_averaged(self):
        rows = [dict(time=10, role='receiver', stages={'mainQueueMs':
                    dict(n=20, p50=1, p95=p95, max=200, over50=1)}) for p95 in (5, 100)]
        text = '\n'.join('DIAG ' + json.dumps(row) for row in rows)
        result = report.summarize(text)
        self.assertIn('100.00', result)
        self.assertNotIn('RECEIVER TIMINGS MISSING', result)

if __name__ == '__main__':
    unittest.main()
