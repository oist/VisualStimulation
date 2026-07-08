"""
Natural image stimulus.

Displays a fixed set of N natural images (e.g. from ImageNet) sampled randomly, without
replacement, from img_dir. Each image is shown for t1 seconds at a fixed screen location (pos),
scaled to a fixed size. There is no blank frame between images - one image's last frame is
immediately followed by the next image's first frame. The same set of N images is presented
`repeats` times, with a freshly shuffled order each repeat.

All N sampled images are preloaded as visual.ImageStim objects (textures uploaded to the GPU)
before the trial loop starts. With up to ~2000 images at ~0.1 MB each on disk, decoding and
uploading a fresh texture on every frame would risk missed flips and jittered t1 timing; since
only the N sampled images are ever used in a session, preloading just those avoids disk I/O and
JPEG decoding inside the timed presentation loop.

Key bindings:
    Escape      : end session

Parameters (NaturalImageParams):
    img_dir  : directory containing square .jpg images (varying pixel sizes)
    N        : number of images to sample (without replacement) from img_dir
    pos      : screen position at which every image is drawn (pix)
    size     : displayed image size, size x size (pix)
    t1       : duration of each image presentation (s)
    repeats  : number of times the same set of N images is presented
"""
from psychopy import visual, core, event, data, logging
import numpy as np
import glob
import os
from datetime import datetime
from serial import Serial
import time
from dataclasses import dataclass
from typing import Tuple


@dataclass
class NaturalImageParams:
    img_dir: str = r"D:\images\imagenet_crops"
    N: int = 100
    pos: Tuple[float, float] = (0.0, 0.0)
    size: float = 200.0
    t1: float = 0.5
    repeats: int = 10


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off):
    dlp = Serial(port=com_port, baudrate=115200)
    dlp.write(code_off)

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw")
    log_filename = os.path.join(logdir, f"log_{exp_name}_{dt_string}")
    log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                         extraInfo={},
                                         runtimeInfo=None,
                                         dataFileName=log_filename,
                                         saveWideText=True,
                                         savePickle=False)

    win = visual.Window(monitor=monitor_name, size=[1280, 720], screen=screen_idx,
                        units='pix', color=[-1, -1, -1], allowGUI=False, waitBlanking=True)

    all_paths = sorted(glob.glob(os.path.join(p.img_dir, "*.jpg")))
    sampled_paths = np.random.choice(all_paths, size=p.N, replace=False)

    # preload all sampled images as textures before the timed presentation loop
    image_stims = []
    image_names = []
    for path in sampled_paths:
        stim = visual.ImageStim(win, image=path, pos=p.pos, size=p.size, units='pix')
        image_stims.append(stim)
        image_names.append(os.path.basename(path))

    trial_num = 0
    clock = core.Clock()

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break
        keys = event.getKeys()
        if keys:
            break

    time.sleep(5.0)

    try:
        for rep in range(p.repeats):
            order = np.random.permutation(len(image_stims))
            for idx in order:
                stim = image_stims[idx]
                name = image_names[idx]
                trial_num += 1

                exp_handler.addData('trial', trial_num)
                exp_handler.addData('repeat', rep)
                exp_handler.addData('image', name)
                exp_handler.nextEntry()
                print(f"  Trial {trial_num}: repeat={rep + 1}/{p.repeats}, image={name}")

                first_frame = True
                event.clearEvents()
                clock.reset()
                while clock.getTime() < p.t1:
                    dlp.write(code_on if first_frame else code_off)
                    first_frame = False
                    stim.draw()
                    win.flip()
                    if event.getKeys(['escape']):
                        raise StopIteration

    except StopIteration:
        pass

    time.sleep(5.0)

    exp_handler.close()

    # TTL to signal the end of the stimuli
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20260702"
    p = NaturalImageParams(
        img_dir=r"C:\Users\tomoy\Documents\visual_stim\20260708_download_imagenet",
        N=1000,
        pos=(0.0, 0.0),
        size=300.0,
        t1=0.5,
        repeats=1,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = "COM3"
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
