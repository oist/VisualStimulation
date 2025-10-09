from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial
from thorlabs_elliptec import ELLx

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20251006"
    repeats = 12
    orientations = [0.0, 11.25, 22.5, 33.75, 45.0, 56.25, 67.5, 78.75, 90.0, 101.25, 112.5, 123.75, 135.0, 146.25, 157.5, 168.75]
    # orientations = [0, 45, 90, 135, 180]
    offset = -3.0
    t1 = 3.0
    t2 = 2.0
    t3 = 1.0
    com_port = "COM3" # for DLP-IO8-G
    com_port_elliptec = "COM4" # for ELL18
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw.log")
    log_filename =  os.path.join(logdir, f"log_{exp_name}_{dt_string}.csv")
    # this is to log all events
    log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=log_filename,
                                        saveWideText=True,
                                        savePickle=False)

    # initialize projector
    win_lum = visual.Window(monitor='test', size=[1280,720], screen=1, fullscr=True,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    framerate = win_lum.getActualFrameRate()
    rect = visual.rect.Rect(win=win_lum, size=[1280,720], pos=[0,0])

    # initialize rotation stage
    stage = ELLx(serial_port="COM4")
    print(f"{stage.model_number} #{stage.device_id} on {stage.port_name}, serial number {stage.serial_number}, status {stage.status.description}")
    resp = stage._write_command("sv64")
    stage.home()
    stage.wait()

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            event.clearEvents()
            break

    frame_counter = 0
    stop_loop = False
    if dlp is not None:
        dlp.write(code_off)
    
    time.sleep(5.0)

    for rep in range(repeats):
        time.sleep(4.0)
        if stop_loop == True:
            break
        for ori in orientations:
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('ori', ori)
            exp_handler.addData('rep', rep)
            # rotate screen
            stage.move_absolute(ori + offset)

            # OFF state
            for i in range(int(t1 * framerate)):
                if dlp is not None:
                    dlp.write(code_off)
                frame_counter += 1
                rect.fillColor = (-1, -1, -1)
                rect.draw()
                win_lum.flip()
            
            actual_pos = stage.get_position()
            is_moving = stage.is_moving()
            exp_handler.addData('actual_ori', actual_pos-offset)
            exp_handler.addData('is_moving', is_moving)
            exp_handler.nextEntry()

            # ON state
            for i in range(int(t2 * framerate)):
                if dlp is not None:
                    dlp.write(code_on)
                frame_counter += 1
                rect.fillColor = (1, 1, 1)
                rect.draw()
                win_lum.flip()
            # OFF state
            for i in range(int(t3 * framerate)):
                if dlp is not None:
                    dlp.write(code_off)
                frame_counter += 1
                rect.fillColor = (-1, -1, -1)
                rect.draw()
                win_lum.flip()
            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
                break

    time.sleep(10.0)
    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
