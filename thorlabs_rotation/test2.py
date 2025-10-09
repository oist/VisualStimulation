from thorlabs_elliptec import ELLx
import time

stage = ELLx(serial_port="COM4")
print(f"{stage.model_number} #{stage.device_id} on {stage.port_name}, serial number {stage.serial_number}, status {stage.status.description}")

resp = stage._write_command("sv48")
resp = stage._write_command("gv")
stage.home()
stage.wait()

stage.move_absolute(-3)
stage.wait()

#resp = stage._write_command("sv28")
#resp = stage._write_command("gv")
#print(resp)
#
#time.sleep(3.0)
#t0 = time.perf_counter()
#stage.move_relative(180.0, blocking=True)
## stage.wait()
#t1 = time.perf_counter()
#print(t1 - t0)

step_deg = 45
n = int(180/step_deg)
dt = 10.0 / n
print(dt)

timestamps = []
for _ in range(n):
    t0 = time.perf_counter()
    stage.move_relative(step_deg)
    # stage.wait()
    time.sleep(dt)
    t1 = time.perf_counter()
    timestamps.append(t1 - t0)

print(timestamps)

stage.close()
