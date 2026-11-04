"""Headless checks: python3 -m unittest discover -s psychopy/test -p test_grid_sweep_v5.py"""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import numpy as np


SCRIPT = Path(__file__).resolve().parents[1] / "PhR_cfc" / "main_grid_sweep_v5.py"
SPEC = importlib.util.spec_from_file_location("grid_sweep_v5", SCRIPT)
grid = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = grid
SPEC.loader.exec_module(grid)


def transition_counts(sequence, n):
    counts = np.zeros((n, n), dtype=int)
    np.add.at(counts, (sequence[:-1], sequence[1:]), 1)
    return counts


class ScheduleTests(unittest.TestCase):
    def test_balanced_counts_across_sizes_repeats_and_seeds(self):
        for n in range(2, 12):
            for repeat in (1, 2, 3, 4, 5, 7, 10, 49, 50, 51):
                for seed in range(20):
                    with self.subTest(n=n, repeat=repeat, seed=seed):
                        seq = grid.make_trial_sequence(n, repeat, np.random.default_rng(seed))
                        self.assertEqual(len(seq), n * repeat)
                        np.testing.assert_array_equal(np.bincount(seq, minlength=n), [repeat] * n)
                        counts = transition_counts(seq, n)
                        self.assertFalse(counts.diagonal().any())
                        off_diagonal = counts[~np.eye(n, dtype=bool)]
                        self.assertLessEqual(off_diagonal.max() - off_diagonal.min(), 1)
                        self.assertEqual(counts.sum(), n * repeat - 1)

    def test_requested_session(self):
        seq = grid.make_trial_sequence(6, 50, np.random.default_rng(42))
        counts = transition_counts(seq, 6)
        self.assertEqual(sorted(counts[~np.eye(6, dtype=bool)]), [9] + [10] * 29)
        other = grid.make_trial_sequence(6, 50, np.random.default_rng(43))
        self.assertNotEqual(seq, other)

    def test_invalid_schedule_parameters(self):
        for n, repeat in ((0, 50), (1, 50), (6, 0), (6, -1), (6, 1.5)):
            with self.assertRaises(ValueError):
                grid.make_trial_sequence(n, repeat, np.random.default_rng(0))


class GridCoverageTests(unittest.TestCase):
    def test_all_visible_lattice_points_are_present_at_every_spacing_and_rotation(self):
        spacing, diameter = 10.87, 5.435
        # Oversized independent reference lattice; compare every circle intersecting
        # the viewport, including circles whose centers are just outside the edges.
        x, y = np.meshgrid(np.arange(-150, 151), np.arange(-150, 151))
        indices = np.column_stack((x.ravel(), y.ravel()))
        for window_size in ((320, 180), (180, 320), (512, 384)):
            for A in (np.eye(2), np.array([[0.83165, 0.11385], [-1.03903, 1.06019]]),
                      np.array([[-0.8, 0.36], [0.16, 1.2]])):
                base = grid.make_grid_xys(window_size, spacing, diameter, A)
                base_indices = base / spacing
                np.testing.assert_allclose(base_indices, np.rint(base_indices), atol=1e-12)
                present = {tuple(index) for index in np.rint(base_indices).astype(int)}
                self.assertIn((0, 0), present)
                for angle in (0, 17.3, 51.3, 90, 137, 179.9):
                    c, s = np.cos(np.deg2rad(angle)), np.sin(np.deg2rad(angle))
                    rotation = np.array([[c, -s], [s, c]])
                    for multiplier in (1, 2, 4):
                        reference = indices * (spacing * multiplier) @ rotation.T @ A.T
                        outside = np.maximum(np.abs(reference) - np.array(window_size) / 2, 0)
                        visible = np.linalg.norm(outside, axis=1) <= diameter / 2
                        required = {tuple(index) for index in indices[visible]}
                        self.assertTrue(required <= present,
                                        (window_size, A, angle, multiplier))

    def test_collapsed_grid_is_rejected(self):
        for A in ([[0, 0], [0, 1]], [[1, 1], [1, 1]]):
            with self.assertRaisesRegex(ValueError, "invertible"):
                grid.make_grid_xys((1280, 720), 10.87, 5.435, A)

    def test_invalid_matrix_shape_or_values_are_rejected(self):
        for A in ([1, 2], np.eye(3), [[np.nan, 0], [0, 1]], [[1, np.inf], [0, 1]]):
            with self.assertRaisesRegex(ValueError, "finite 2x2"):
                grid.make_grid_xys((1280, 720), 10.87, 5.435, A)

    def test_requested_default_matrix(self):
        np.testing.assert_array_equal(grid.SweepParams().A,
                                      [[0.83165, 0.11385], [-1.03903, 1.06019]])


class PresentationTests(unittest.TestCase):
    def run_session(self, t1, escape_at=None, sleep_before=0, sleep_after=0,
                    connected=False):
        """Simulate time and front/back buffers without a display or serial device."""
        class Clock:
            def reset(self):
                self.elapsed = 0.0

            def getTime(self):
                self.elapsed += 0.01
                return self.elapsed

        class Window:
            size = (1280, 720)
            color = [-1.0] * 3
            back_color = (-1.0,) * 3
            drawn = False

            def clearBuffer(self):
                self.back_color = tuple(self.color)
                self.drawn = False

            def flip(self):
                frames.append((self.back_color, self.drawn))
                self.clearBuffer()

            def close(self):
                pass

        frames, rows = [], []
        row = {}
        win = Window()
        stim = Mock()
        stim.draw.side_effect = lambda: setattr(win, "drawn", True)

        def make_stim(*args, **kwargs):
            stim.xys = kwargs["xys"]
            return stim

        handler = Mock()
        handler.addData.side_effect = lambda key, value: row.update({key: value})

        def next_entry():
            rows.append(dict(row))
            fake.presented_xys.append(stim.xys[[0, len(stim.xys) // 2, -1]].copy())
            row.clear()

        handler.nextEntry.side_effect = next_entry

        def get_keys(keyList=None):
            self.assertEqual(keyList, ["escape"])
            if escape_at is not None and len(frames) >= escape_at:
                return ["escape"]
            return []

        fake = SimpleNamespace(
            visual=SimpleNamespace(Window=Mock(return_value=win),
                                   ElementArrayStim=Mock(side_effect=make_stim)),
            core=SimpleNamespace(Clock=Clock),
            event=SimpleNamespace(getKeys=get_keys, clearEvents=Mock()),
            data=SimpleNamespace(ExperimentHandler=Mock(return_value=handler)),
            logging=SimpleNamespace(LogFile=Mock(), EXP=1, exp=Mock()),
            presented_xys=[],
        )
        params = grid.SweepParams(t1=t1, t2=0.025, spacing_range=[10.87, 21.74, 43.48],
                                 repeat=5,
                                 sleep_before=sleep_before, sleep_after=sleep_after)
        device = Mock()
        device.read.return_value = b'1\r\n'
        serial = SimpleNamespace(Serial=Mock(return_value=device))
        output = io.StringIO()
        with patch.dict(sys.modules, {"psychopy": fake, "serial": serial}), \
                patch.object(grid.time, "sleep"), \
                patch.object(grid, "print_transition_matrix") as print_matrix, \
                contextlib.redirect_stdout(output):
            grid.main(params, "test", "/tmp", "test", 0, "test-port" if connected else None)
        fake.visual.Window.assert_called_once()
        self.assertFalse(fake.visual.Window.call_args.kwargs["fullscr"])
        self.assertEqual(fake.visual.Window.call_args.kwargs["size"], [1280, 720])
        fake.visual.ElementArrayStim.assert_called_once()
        self.assertEqual(len(stim.xys), fake.visual.ElementArrayStim.call_args.kwargs["nElements"])
        if connected:
            serial.Serial.assert_called_once_with(port="test-port", baudrate=115200, timeout=0.05)
            device.close.assert_called_once()
            commands = [call.args[0] for call in device.write.call_args_list]
            self.assertNotIn(b'4', commands)
            self.assertNotIn(b'R', commands)
        return frames, rows, print_matrix.call_args.args[1], fake

    def test_background_and_rotation_logging_with_and_without_blank(self):
        for t1 in (0, 0.025):
            with self.subTest(t1=t1):
                frames, rows, counts, fake = self.run_session(t1)
                self.assertEqual(len(rows), 30)
                angles = [row["theta_sampled"] for row in rows]
                self.assertTrue(all(0 <= angle < 180 for angle in angles))
                self.assertEqual(len(set(angles)), len(angles))
                blank_frames = 0 if t1 == 0 else 2
                per_trial = blank_frames + 3
                self.assertEqual(len(frames), len(rows) * per_trial)
                for i, row in enumerate(rows):
                    trial_frames = frames[i * per_trial:(i + 1) * per_trial]
                    self.assertEqual([drawn for _, drawn in trial_frames],
                                     [False] * blank_frames + [True] * 3)
                    for background, _ in trial_frames:
                        self.assertEqual(background, (row["background_brightness"],) * 3)
                    self.assertEqual(row["theta"], row["theta_sampled"])
                seq = [row["condition"] for row in rows]
                np.testing.assert_array_equal(counts, transition_counts(seq, 6))
                np.testing.assert_array_equal(np.bincount(seq, minlength=6), [5] * 6)
                fake.data.ExperimentHandler.return_value.close.assert_called_once()

    def test_escape_counts_presented_but_incomplete_stimulus(self):
        frames, rows, counts, _ = self.run_session(0, escape_at=4)
        self.assertEqual(len(frames), 4)  # One complete stimulus, then one frame.
        self.assertEqual(len(rows), 1)
        self.assertEqual(counts.sum(), 1)

    def test_presented_positions_rotate_then_apply_A_and_log_matrix(self):
        _, rows, _, fake = self.run_session(0)
        base = fake.visual.ElementArrayStim.call_args.kwargs["xys"]
        sample = base[[0, len(base) // 2, -1]]
        for row, actual in zip(rows, fake.presented_xys):
            x, y = (sample * (row["spacing"] / 10.87)).T
            angle = np.deg2rad(row["theta_sampled"])
            rotated_x = x * np.cos(angle) - y * np.sin(angle)
            rotated_y = x * np.sin(angle) + y * np.cos(angle)
            expected = np.column_stack((0.83165 * rotated_x + 0.11385 * rotated_y,
                                        -1.03903 * rotated_x + 1.06019 * rotated_y))
            np.testing.assert_allclose(actual, expected, atol=1e-10)
            self.assertEqual([row[key] for key in ("A00", "A01", "A10", "A11")],
                             [0.83165, 0.11385, -1.03903, 1.06019])
            self.assertEqual(row["transform_order"], "A @ R")
            self.assertTrue({"sx", "sy", "kx", "ky"}.isdisjoint(row))

    def test_escape_in_blank_does_not_count_unshown_stimulus(self):
        frames, rows, counts, _ = self.run_session(0.025, escape_at=6)
        self.assertEqual(len(frames), 6)  # One complete trial, then one blank frame.
        self.assertEqual(len(rows), 1)
        self.assertEqual(counts.sum(), 0)

    def test_escape_during_initial_delay_or_ttl_wait(self):
        for connected in (False, True):
            with self.subTest(connected=connected):
                frames, rows, counts, _ = self.run_session(
                    0, escape_at=0, sleep_before=1, connected=connected)
                self.assertEqual(frames, [])
                self.assertEqual(rows, [])
                self.assertEqual(counts.sum(), 0)

    def test_ttl_start_and_escape_during_final_delay(self):
        frames, rows, counts, _ = self.run_session(
            0, escape_at=90, sleep_after=1, connected=True)
        self.assertEqual(len(frames), 90)
        self.assertEqual(len(rows), 30)
        self.assertEqual(counts.sum(), 29)


if __name__ == "__main__":
    unittest.main()
