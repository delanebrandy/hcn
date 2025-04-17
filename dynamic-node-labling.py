# monitor_idle_labels.py
# ------------------------------------------------------------
# Continuously monitors system usage and battery status.
# Updates Kubernetes node labels dynamically based on conditions:
# - CPU usage below threshold
# - Plugged in or battery level > 80%
# Applies or removes `idle=true` label accordingly.
# ------------------------------------------------------------

import subprocess
import time
import psutil
import platform

NODE_NAME_CMD = ["hostname"]
LABEL_CMD = "kubectl label node {node} {key}={value} --overwrite"
UNLABEL_CMD = "kubectl label node {node} {key}-"

# Configurable thresholds
CPU_IDLE_THRESHOLD = 20  
BATTERY_THRESHOLD = 80   
SAMPLE_INTERVAL = 60     


def get_node_name():
    return subprocess.check_output(NODE_NAME_CMD).decode().strip()


def is_plugged_in_and_sufficient():
    battery = psutil.sensors_battery()
    if battery is None:
        return True  # Assume plugged in if battery can't be read
    return battery.power_plugged or battery.percent >= BATTERY_THRESHOLD


def is_cpu_idle():
    return psutil.cpu_percent(interval=1) < CPU_IDLE_THRESHOLD


def label_node(node, key, value):
    cmd = LABEL_CMD.format(node=node, key=key, value=value)
    subprocess.run(cmd.split(), check=True)


def unlabel_node(node, key):
    cmd = UNLABEL_CMD.format(node=node, key=key)
    subprocess.run(cmd.split(), check=True)


def monitor():
    node = get_node_name()
    print(f"[Monitor] Monitoring node: {node}")
    
    while True:
        idle = is_cpu_idle()
        power_ok = is_plugged_in_and_sufficient()

        try:
            if idle and power_ok:
                print("[Monitor] Node is idle and power OK — applying label idle=true")
                label_node(node, "idle", "true")
            else:
                print("[Monitor] Node is busy or on battery — removing label idle")
                unlabel_node(node, "idle")
        except subprocess.CalledProcessError as e:
            print(f"[Monitor] Failed to label node: {e}")

        time.sleep(SAMPLE_INTERVAL)


if __name__ == "__main__":
    monitor()
