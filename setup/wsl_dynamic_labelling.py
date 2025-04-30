import subprocess
import sys

NODE_NAME_CMD = ["hostname"]
LABEL_CMD     = ["kubectl", "label", "node"]
TAINT_CMD     = ["kubectl", "taint", "node"]

def get_node_name():
    return subprocess.check_output(NODE_NAME_CMD).decode().strip().lower()

def label_node(node, key, value):
    cmd = LABEL_CMD + [node, f"{key}={value}", "--overwrite"]
    subprocess.run(cmd, check=True)

def taint_node(node, key, value):
    # keep the label in sync, then taint
    label_node(node, key, value)
    cmd = TAINT_CMD + [node, f"{key}={value}:NoSchedule", "--overwrite"]
    subprocess.run(cmd, check=True)

def main():
    node = get_node_name()
    print(f"[Labeler] Target node: {node}", file=sys.stderr)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            parts = dict(item.split("=",1) for item in line.split())
            idle = parts.get("idle")     == "true"
            power_ok = parts.get("power_ok") == "true"

            if idle and power_ok:
                print("[Labeler] idle & power OK: labeling idle=true", file=sys.stderr)
                label_node(node, "idle", "true")
            else:
                print("[Labeler] busy or on battery: tainting idle=false", file=sys.stderr)
                taint_node(node, "idle", "false")

        except Exception as e:
            print(f"[Labeler] failed to parse or apply: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
