import time, sys
import psutil

CPU_IDLE_THRESHOLD = 30
BATTERY_THRESHOLD = 70
SAMPLE_INTERVAL = 30

def is_cpu_idle():
    cpu = psutil.cpu_percent(interval=1)
    print(f"[Monitor] CPU usage: {cpu:.1f}%", file=sys.stderr)
    return cpu < CPU_IDLE_THRESHOLD

def is_plugged_in_and_sufficient():
    battery = psutil.sensors_battery()
    if battery is None:
        return True
    return battery.power_plugged or battery.percent >= BATTERY_THRESHOLD

def main():
    while True:
        idle     = is_cpu_idle()
        power_ok = is_plugged_in_and_sufficient()
        print(f"idle={str(idle).lower()} power_ok={str(power_ok).lower()}", flush=True)
        time.sleep(SAMPLE_INTERVAL)

if __name__ == "__main__":
    main()
