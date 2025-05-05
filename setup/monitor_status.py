import time, sys
import psutil

CPU_IDLE_THRESHOLD = 30
BATTERY_THRESHOLD = 70
SAMPLE_INTERVAL = 30

def is_cpu_idle():
    cpu = psutil.cpu_percent(interval=1)
    print(f"[Monitor] CPU usage: {cpu:.1f}%", file=sys.stderr)
    return cpu < CPU_IDLE_THRESHOLD

def cpu_usage_host():
    return psutil.cpu_percent(interval=1)

def is_plugged_in_and_sufficient():
    battery = psutil.sensors_battery()
    if battery is None:
        return True
    return battery.power_plugged or battery.percent >= BATTERY_THRESHOLD

def cpu_usage_vmmem():
    for proc in psutil.process_iter(['name', 'cpu_percent']):
        name = (proc.info['name'] or '').lower()
        if name in ('vmmem', 'vmmemwsl'):
            return proc.cpu_percent(interval=1)
    return cpu_usage_host()

def main():
    while True:
        idle     = is_cpu_idle()
        vmem_cpu = cpu_usage_vmmem()
        power_ok = is_plugged_in_and_sufficient()
        print(f"idle={str(idle).lower()} power_ok={str(power_ok).lower()} vmem_cpu={vmem_cpu:.1f}", flush=True)
        time.sleep(SAMPLE_INTERVAL)

if __name__ == "__main__":
    main()
