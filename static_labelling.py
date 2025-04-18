# static_labeling.py
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Description: Dynamic performance labeling of nodes in a HCN cluster
#              Combines XML benchmark parsing with Kubernetes node labeling.
# ------------------------------------------------------------------------------

import json
import xml.etree.ElementTree as ET
from pathlib import Path
import subprocess
import argparse
import platform
import shutil
import os

LABEL_MAP = {
    "build-linux-kernel": "cpu",
    "vkmark": "gpu-vulkan",
    "unigine-heaven": "gpu-opengl",
    "octanebench": "gpu-cuda",
    "juliagpu": "gpu-opencl",
}

# ----------------------- Threshold Configuration ------------------------------
THRESHOLDS = {
    "cpu": {"high": 60, "mid": 120},           # lower is better (seconds)
    "gpu-vulkan": {"low": 20, "mid": 60},      # higher is better (FPS)
    "gpu-opengl": {"low": 20, "mid": 60},
    "gpu-cuda": {"low": 20, "mid": 60},
    "gpu-opencl": {"low": 20, "mid": 60},
}

# ------------------------- Classification Logic -------------------------------
def classify(label, value):
    if label == "cpu":
        if value < THRESHOLDS[label]["high"]:
            return "high"
        elif value < THRESHOLDS[label]["mid"]:
            return "mid"
        else:
            return "low"
    else:
        if value > THRESHOLDS[label]["mid"]:
            return "high"
        elif value > THRESHOLDS[label]["low"]:
            return "mid"
        else:
            return "low"

# ------------------------- Kubernetes Labeling --------------------------------
def label_node(node, key, value):
    print(f"[kubectl] Labeling {node}: {key}={value}")
    subprocess.run(["kubectl", "label", "node", node, f"{key}={value}", "--overwrite"], check=True)

# ------------------------- Benchmark Parsing ----------------------------------
def parse_results():
    results = {label: None for label in LABEL_MAP.values()}
    platforms_supported = set()

    for xml in Path.home().glob(".phoronix-test-suite/test-results/*/composite.xml"):
        try:
            root = ET.parse(xml).getroot()
            test_id = root.findtext("Result/Identifier")
            if not test_id:
                continue

            short = test_id.split("/")[-1]         # e.g. build-linux-kernel-1.16.0
            base = short.split("-")[0]             # e.g. build-linux-kernel
            label = LABEL_MAP.get(base)
            if not label:
                continue

            value = float(root.findtext("Result/Data/Entry/Value"))
            results[label] = value
            platforms_supported.add(label)

        except Exception as e:
            print(f"[!] Error parsing {xml}: {e}")
            continue

    return results, platforms_supported

# --------------------------- System Info Detection ----------------------------
def detect_arch():
    return platform.machine().lower()

def detect_gpu_vendor():
    if shutil.which("nvidia-smi"):
        return "nvidia"
    elif shutil.which("clinfo"):
        try:
            out = subprocess.check_output("clinfo", stderr=subprocess.DEVNULL).decode().lower()
            if "intel" in out:
                return "intel"
            elif "amd" in out:
                return "amd"
        except Exception:
            pass
    return "unknown"

def has_battery():
    try:
        power_devices = subprocess.check_output(["upower", "-e"]).decode().splitlines()
        return any("battery" in device for device in power_devices)
    except Exception as e:
        print(f"[WARN] Battery detection failed: {e}")
        return False

# ------------------------------ Main Logic ------------------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--node", required=True, help="Kubernetes node name")
    args = parser.parse_args()

    node = args.node
    results, platforms = parse_results()

    # Save raw parsed data
    with open("node_performance.json", "w") as f:
        json.dump({"node-performance": [results]}, f, indent=2)

    print("[✓] node_performance.json written")

    for label, value in results.items():
        if value is None:
            print(f"[WARN] No result for {label}")
            continue
        perf_class = classify(label, value)
        key = label.replace("gpu-", "gpu") if label.startswith("gpu-") else label
        label_node(node, key, perf_class)

    # Combine supported platforms into a single label
    platforms_flat = [p.replace("gpu-", "") for p in platforms if p != "cpu"]
    if platforms_flat:
        platforms_string = ",".join(sorted(platforms_flat))
        label_node(node, "platforms", platforms_string)

    # Add architecture, vendor, and battery presence
    arch = detect_arch()
    vendor = detect_gpu_vendor()
    has_batt = "true" if has_battery() else "false"

    label_node(node, "arch", arch)
    label_node(node, "vendor", vendor)
    label_node(node, "has-battery", has_batt)

if __name__ == "__main__":
    main()
