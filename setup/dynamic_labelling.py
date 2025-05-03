import subprocess
import time
import psutil
import json

NODE_NAME_CMD = ["hostname"]
LABEL_CMD = "kubectl label node {node} {key}={value} --overwrite"
TAINT_CMD = "kubectl taint node {node} {key}={value}:NoExecute --overwrite"
UNTAINT_CMD = "kubectl taint node {node} {key}={value}:NoExecute- --overwrite"

CPU_IDLE_THRESHOLD = 30
BATTERY_THRESHOLD = 70
SAMPLE_INTERVAL = 30

def get_node_name():
    return subprocess.check_output(NODE_NAME_CMD).decode().strip().lower()


def is_plugged_in_and_sufficient():
    battery = psutil.sensors_battery()
    if battery is None:
        return True
    return battery.power_plugged or battery.percent >= BATTERY_THRESHOLD


def is_cpu_idle():
    usage = psutil.cpu_percent(interval=1)
    print(f"[Monitor] CPU usage: {usage}%")
    return usage < CPU_IDLE_THRESHOLD

def has_taint(node, key, value, effect="NoExecute"):
    try:
        output = subprocess.check_output(
            ["kubectl", "get", "node", node, "-o", "json"]
        )
        data = json.loads(output)
        taints = data.get("spec", {}).get("taints", []) or []
        for taint in taints:
            if (
                taint.get("key") == key
                and taint.get("value") == value
                and taint.get("effect") == effect
            ):
                return True
    except subprocess.CalledProcessError as e:
        print(f"[Monitor] Error fetching taints: {e}")
    return False

def label_node(node, key, value):
    cmd = LABEL_CMD.format(node=node, key=key, value=value).split()
    subprocess.run(cmd, check=True)

def taint_node(node, key, value):
    label_node(node, key, value)
    cmd = TAINT_CMD.format(node=node, key=key, value=value).split()
    subprocess.run(cmd, check=True)

def untaint_node(node, key, value):
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
                print("[Monitor] Node is idle and power OK — applying label idle=true and removing previous idle=false taint if present")
                label_node(node, "idle", "true")
                if has_taint(node, "idle", "false"):
                    untaint_node(node, "idle", "false")
            else:
                print("[Monitor] Node is busy or on battery — applying taint idle=false:NoExecute")
                taint_node(node, "idle", "false")

        except subprocess.CalledProcessError as e:
            print(f"[Monitor] Failed to modify node: {e}")

        time.sleep(SAMPLE_INTERVAL)

if __name__ == "__main__":
    monitor()
