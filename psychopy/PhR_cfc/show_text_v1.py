"""Display text in repeating blank/text cycles.

Edit TextParams in the PARAMETERS block. pos is the fixed text center in pixels.
height is the visible text bounding-box height in pixels before transformation.
The entire text is scaled, simultaneously sheared, then rotated about pos:
A = R @ H @ S, H = [[1, kx], [ky, 1]]. theta is degrees counterclockwise.
font may be a .ttf/.otf/.ttc font path; None automatically selects a Japanese
font for Japanese text, otherwise an available Latin font. For example, set
text='イカ' and font=None, or specify a Japanese font file explicitly.

Keys (active while waiting, during delays, and during blank/text periods):
    Space / Enter : start (or an external TTL when DLP is connected)
    Escape        : quit
    1 / 2         : theta +/- 5 degrees
    3 / 4         : sx +/- 0.1
    5 / 6         : kx +/- 0.1
    7 / 8         : height +/- 1 pixel (minimum 1)

Adjustments persist across cycles. CSV rows contain final cycle values; the raw
log records individual adjustments. com_port=None disables all DLP operations.
Requires PsychoPy, NumPy and Pillow; pyserial is needed only when DLP is enabled.
"""
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple
from math import floor, ceil
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from psychopy import visual, core, event, data, logging
# PsychoPy visual classes are lazy imports; use the full path for subclassing.
from psychopy.visual.image import ImageStim


@dataclass
class TextParams:
    text: str = "squid"
    pos: Tuple[float, float] = (0.0, 0.0)
    height: float = 60.0
    font: Optional[str] = None
    t1: float = 0.5
    t2: float = 0.5
    repeat: int = 30
    bg_brightness_t1: float = -1.0
    bg_brightness_t2: float = -1.0
    text_brightness: float = 1.0
    theta: float = 0.0
    sx: float = 1.0
    sy: float = 1.0
    kx: float = 0.0
    ky: float = 0.0
    display_info: bool = True
    sleep_before: float = 5.0
    sleep_after: float = 5.0


KEY_ADJUSTMENTS = {
    '1': ('theta', 5.0), '2': ('theta', -5.0),
    '3': ('sx', 0.1), '4': ('sx', -0.1),
    '5': ('kx', 0.1), '6': ('kx', -0.1),
    '7': ('height', 1.0), '8': ('height', -1.0),
}


def apply_key(p, key):
    """Apply one adjustment and return whether the key was recognized."""
    if key not in KEY_ADJUSTMENTS:
        return False
    name, delta = KEY_ADJUSTMENTS[key]
    value = round(getattr(p, name) + delta, 10)
    setattr(p, name, max(1.0, value) if name == 'height' else value)
    return True


def transformation_matrix(theta, sx, sy, kx, ky):
    angle = np.deg2rad(theta)
    c, s = np.cos(angle), np.sin(angle)
    rotation = np.array([[c, -s], [s, c]])
    shear = np.array([[1.0, kx], [ky, 1.0]])
    return rotation @ shear @ np.diag([sx, sy])


def make_text_image(text, font=None):
    """Rasterize once at high resolution; size adjustments reuse this texture."""
    windows_fonts = Path(os.environ.get('WINDIR', 'C:/Windows')) / 'Fonts'
    japanese = any(
        '\u3000' <= char <= '\u30ff' or '\u3400' <= char <= '\u9fff'
        or '\uf900' <= char <= '\ufaff' or '\uff00' <= char <= '\uffef'
        or '\U00020000' <= char <= '\U000323af'
        for char in text
    )
    japanese_fonts = [
        str(windows_fonts / 'meiryo.ttc'),
        str(windows_fonts / 'YuGothM.ttc'),
        str(windows_fonts / 'msgothic.ttc'),
        '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc',
        '/System/Library/Fonts/ヒラギノ角ゴシック W3.otf',
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        '/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc',
    ]
    latin_fonts = [
        'DejaVuSans.ttf', 'Arial.ttf',
        str(windows_fonts / 'arial.ttf'),
        '/System/Library/Fonts/Supplemental/Arial.ttf',
    ]
    candidates = [font] if font else (japanese_fonts if japanese else latin_fonts)
    for candidate in candidates:
        try:
            face = ImageFont.truetype(candidate, 256)
            break
        except OSError:
            continue
    else:
        raise ValueError(
            'No suitable font found. Set font to a .ttf, .otf or .ttc file '
            'that supports your text (for Japanese, e.g. Meiryo or Noto Sans CJK JP).'
        )
    probe = ImageDraw.Draw(Image.new('L', (1, 1)))
    if hasattr(probe, 'multiline_textbbox'):
        left, top, right, bottom = probe.multiline_textbbox(
            (0, 0), text, font=face, align='center')
    else:  # Older Pillow versions bundled with some PsychoPy installations.
        left = top = 0
        right, bottom = probe.multiline_textsize(text, font=face)
    # Font measurements can be fractional. Round outward to integer pixel
    # bounds so Pillow accepts the dimensions without clipping glyph edges.
    left, top = floor(left), floor(top)
    right, bottom = ceil(right), ceil(bottom)
    mask = Image.new('L', (max(1, right-left), max(1, bottom-top)), 0)
    ImageDraw.Draw(mask).multiline_text((-left, -top), text, font=face, fill=255, align='center')
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError('text must contain at least one visible character.')
    mask = mask.crop(bounds)
    # Transparent padding avoids sampling the glyph edge at the texture boundary.
    image = Image.new('RGBA', (mask.width + 4, mask.height + 4), (255, 255, 255, 0))
    image.paste(Image.new('RGBA', mask.size, (255, 255, 255, 255)), (2, 2))
    alpha = Image.new('L', image.size, 0)
    alpha.paste(mask, (2, 2))
    image.putalpha(alpha)
    return image, mask.height


class AffineTextStim(ImageStim):
    """Transform a textured quad, including glyphs, about its fixed pixel center."""
    def __init__(self, win, p):
        self.transform = transformation_matrix(p.theta, p.sx, p.sy, p.kx, p.ky)
        image, self.glyph_height = make_text_image(p.text, p.font)
        self.texture_size = np.asarray(image.size, dtype=float)
        super().__init__(win, image=image, units='pix', pos=p.pos,
                         size=self.texture_size * p.height / self.glyph_height,
                         color=[p.text_brightness] * 3, colorSpace='rgb',
                         interpolate=True, autoLog=False)

    @property
    def verticesPix(self):
        vertices = super().verticesPix
        center = np.asarray(self.pos, dtype=float)
        return (vertices - center) @ self.transform.T + center

    def update_params(self, p):
        self.transform = transformation_matrix(p.theta, p.sx, p.sy, p.kx, p.ky)
        self.size = self.texture_size * p.height / self.glyph_height
        # Also invalidate legacy OpenGL's cached geometry.
        self._needUpdate = True


class SessionStopped(Exception):
    pass


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port=None,
         code_on=b'1', code_off=b'Q'):
    if not np.isfinite(p.height) or p.height < 1:
        raise ValueError('height must be finite and at least 1 pixel.')
    for name in ('t1', 't2', 'sleep_before', 'sleep_after'):
        value = getattr(p, name)
        if not np.isfinite(value) or value < 0:
            raise ValueError(f'{name} must be finite and nonnegative.')
    if p.t1 + p.t2 <= 0 or p.repeat < 1:
        raise ValueError('Use a positive cycle duration and at least one repeat.')
    Path(logdir).mkdir(parents=True, exist_ok=True)
    stem = Path(logdir) / f"log_{exp_name}_{datetime.now():%Y%m%d_%H%M%S}"
    raw_log = logging.LogFile(str(stem) + '_raw.log', level=logging.EXP)
    exp = data.ExperimentHandler(name=exp_name, extraInfo=asdict(p),
                                 dataFileName=str(stem), saveWideText=True, savePickle=False)
    win = dlp = None
    trial = 0
    try:
        if com_port is not None:
            from serial import Serial
            dlp = Serial(port=com_port, baudrate=115200, timeout=0.01)
            dlp.write(code_off)
        win = visual.Window(monitor=monitor_name, size=[1280, 720], screen=screen_idx,
                            units='pix', color=[p.bg_brightness_t1]*3,
                            allowGUI=False, waitBlanking=True)
        text = AffineTextStim(win, p)
        info = visual.TextStim(win, pos=(-win.size[0]/2+15, win.size[1]/2-20),
                               anchorHoriz='left', anchorVert='top', height=16,
                               color=(-1, 1, -1), units='pix', autoLog=False)

        def handle_keys():
            keys = event.getKeys()
            if 'escape' in keys:
                raise SessionStopped
            changed = False
            for key in keys:
                if apply_key(p, key):
                    name, _ = KEY_ADJUSTMENTS[key]
                    logging.exp(f'Trial {trial}: key={key}, {name}={getattr(p, name):g}')
                    changed = True
            if changed:
                text.update_params(p)
            return keys

        def draw_info(waiting=False):
            if p.display_info:
                info.text = (
                    f'trial={trial}/{p.repeat}  height={p.height:g} px\n'
                    f'theta={p.theta:g} deg  scale=({p.sx:g}, {p.sy:g})  '
                    f'shear=({p.kx:g}, {p.ky:g})\n'
                    '1/2: theta   3/4: sx   5/6: kx   7/8: height   Esc: quit'
                    + ('\nSpace / Enter or TTL to start' if waiting else '')
                )
                info.draw()

        def run_phase(duration, show_text=False):
            win.color = [p.bg_brightness_t2 if show_text else p.bg_brightness_t1]*3
            timer = core.Clock()
            first_frame = True
            while timer.getTime() < duration:
                handle_keys()
                if show_text:
                    text.draw()
                    if dlp is not None:
                        win.callOnFlip(dlp.write, code_on if first_frame else code_off)
                draw_info()
                win.flip()
                first_frame = False
            if show_text and dlp is not None:
                dlp.write(code_off)

        while True:
            keys = handle_keys()
            if 'space' in keys or 'return' in keys:
                break
            if dlp is not None:
                dlp.write(b'S')
                if dlp.read(3).startswith(b'1'):
                    break
            draw_info(waiting=True)
            win.flip()

        run_phase(p.sleep_before)
        for trial in range(1, p.repeat + 1):
            run_phase(p.t1)
            run_phase(p.t2, show_text=True)
            exp.addData('trial', trial)
            for name, value in asdict(p).items():
                exp.addData(name, value)
            exp.nextEntry()
        # Remove the last text frame even if sleep_after is zero.
        win.color = [p.bg_brightness_t1]*3
        win.flip()
        run_phase(p.sleep_after)
    except SessionStopped:
        pass
    finally:
        try:
            if dlp is not None:
                try:
                    dlp.write(code_off)
                    dlp.write(b'3')
                    core.wait(0.1)
                    dlp.write(b'E')
                finally:
                    dlp.close()
        finally:
            if win is not None:
                win.close()
            exp.close()
            logging.flush()
            raw_log.logger.removeTarget(raw_log)
            raw_log.stream.close()


if __name__ == '__main__':
    ###### PARAMETERS BEGIN ######
    p = TextParams(
        # text='squid',
        text='イカ',
        pos=(0.0, 0.0),
        height=30.0,
        font=None,  # Or a full path to a .ttf/.otf font.
        t1=2,
        t2=2,
        repeat=30,
        theta=51.3,
        sx=1.0/1.77,
        sy=1.0,
        kx=1.0,
        ky=0.0,
        display_info=True,
        sleep_before=1.0,
        sleep_after=1.0,
    )
    exp_name = 'show_text'
    logdir = Path(__file__).resolve().parent / 'logs'
    monitor_name = 'testMonitor'
    screen_idx = 0
    com_port = None  # For example 'COM3' to enable DLP communication.
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######
    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
