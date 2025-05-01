# dynamic_labelling.py
# ------------------------------------------------------------
# Continuously monitors system usage and battery status.
# Updates Kubernetes node labels dynamically based on conditions:
# - CPU usage below threshold
# - Plugged in or battery level > 80%
# Modifies`idle=true` taint on the control plane.
# ------------------------------------------------------------

import subprocess
import time
import psutil
import sys

NODE_NAME_CMD = ["hostname"]
LABEL_CMD = "kubectl label node {node} {key}={value} --overwrite"
TAINT_CMD = "kubectl taint node {node} {key}={value}:NoExecute --overwrite"
UNTAINT_CMD = "kubectl taint node {node} {key}={value}:NoExecute- --overwrite"

# Configurable thresholds
CPU_IDLE_THRESHOLD = 30  
BATTERY_THRESHOLD = 70   
SAMPLE_INTERVAL = 60     

def get_node_name():
    return subprocess.check_output(NODE_NAME_CMD).decode().strip().lower()


def is_plugged_in_and_sufficient():
    battery = psutil.sensors_battery()
    if battery is None:
        return True  # Assume plugged in if battery can't be read
    return battery.power_plugged or battery.percent >= BATTERY_THRESHOLD


def is_cpu_idle():
    print (f"[Monitor] CPU usage: {psutil.cpu_percent(interval=1)}%")
    return psutil.cpu_percent(interval=1) < CPU_IDLE_THRESHOLD


def label_node(node, key, value):
    # build remote kubectl label command
    cmd = LABEL_CMD.format(node=node, key=key, value=value).split()
    subprocess.run(cmd, check=True)


def taint_node(node, key, value):
    # build remote kubectl taint command
    label_node(node, key, value)
    cmd = TAINT_CMD.format(node=node, key=key, value=value).split()

def untaint_node(node, key, value):
    # build remote kubectl untaint command
    cmd = UNTAINT_CMD.format(node=node, key=key, value=value).split()
    subprocess.run(cmd, check=True)

def monitor():
    node = get_node_name()
    print(f"[Monitor] Monitoring node: {node}")

    while True:
        idle = is_cpu_idle()
        power_ok = is_plugged_in_and_sufficient()

        try:
            if idle and power_ok:
                ##check if the node is already labelled
                cmd = ["kubectl", "get", "node", node, "-o", "jsonpath='{.metadata.labels.idle}'"]
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                if result.stdout.strip() == "true":
                    print("[Monitor] Node already labelled as idle")
                else:
                    print("[Monitor] Node is idle and power OK — applying label idle=true")
                    label_node(node, "idle", "true")
                    untaint_node(node, "idle", "false")
            else:
                print("[Monitor] Node is busy or on battery — removing label idle")
                taint_node(node, "idle", "false")

        except subprocess.CalledProcessError as e:
            print(f"[Monitor] Failed to label node: {e}")

        time.sleep(SAMPLE_INTERVAL)


if __name__ == "__main__":
    monitor()
