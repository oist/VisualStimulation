import elliptec
import time
controller = elliptec.Controller('COM4')
ro = elliptec.Rotator(controller)

# Home the rotator before usage
ro.home()

#step_deg = 1.0
#n = int(90/step_deg)
#dt = 6.0 / n
#
#current = 0
#for _ in range(n):
#    ro.set_angle(current)
#    current += step_deg
#    time.sleep(dt)
#

step_deg = 2.0
ro.set_jog_step(step_deg)
n = int(90/step_deg)
dt = 6.0 / n
for _ in range(n):
    ro.jog(direction="forward")
    time.sleep(dt)
