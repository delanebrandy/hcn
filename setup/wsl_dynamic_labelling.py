import subprocess
import sys
import json
import psutil

CPU_IDLE_THRESHOLD = 30
CONTAINER_RATIO_THRESHOLD = 0.8

NODE_NAME_CMD = ["hostname"]
LABEL_CMD     = "kubectl label node {node} {key}={value} --overwrite"
TAINT_CMD     = "kubectl taint node {node} {key}={value}:NoExecute --overwrite"
UNTAINT_CMD   = "kubectl taint node {node} {key}={value}:NoExecute- --overwrite"

def get_node_name():
    return subprocess.check_output(NODE_NAME_CMD).decode().strip().lower()

def run_cmd(template: str, **kwargs):
    cmd = template.format(**kwargs).split()
    subprocess.run(cmd, check=True)

def label_node(node, key, value):
    run_cmd(LABEL_CMD, node=node, key=key, value=value)

def taint_node(node, key, value):
    label_node(node, key, value)
    run_cmd(TAINT_CMD, node=node, key=key, value=value)

def untaint_node(node, key, value):
    run_cmd(UNTAINT_CMD, node=node, key=key, value=value)

def has_taint(node: str, key: str, value: str, effect: str = "NoExecute") -> bool:
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
        print(f"[Labeler] Error fetching taints: {e}", file=sys.stderr)
    return False

def is_user_load_present(vmem_cpu, container_ratio_threshold=CONTAINER_RATIO_THRESHOLD):
    container_sum = 0.0
    for proc in psutil.process_iter(['name','cpu_percent']):
        try:
            cpu = proc.info['cpu_percent']
            name = (proc.info['name'] or '').lower()
            if any(x in name for x in ['docker','dockerd','containerd','shim','runc','cri-dockerd']):
                container_sum += cpu
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    container_ratio = container_sum / vmem_cpu if vmem_cpu else 0
    return container_ratio <= container_ratio_threshold

def main():
    node = get_node_name()
    print(f"[Labeler] Target node: {node}", file=sys.stderr)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            parts = dict(item.split("=", 1) for item in line.split())
            idle = parts.get("idle") == "true"
            power_ok = parts.get("power_ok") == "true"
            vmem_cpu = float(parts.get("vmem_cpu", "0"))

            if not idle or not power_ok:
                taint_node(node, "idle", "false")
            elif vmem_cpu > CPU_IDLE_THRESHOLD and is_user_load_present(vmem_cpu):
                taint_node(node, "idle", "false")
            else:
                label_node(node, "idle", "true")
                if has_taint(node, "idle", "false"):
                    untaint_node(node, "idle", "false")

        except Exception as e:
            print(f"[Labeler] failed to parse or apply: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
