# static_labeling.py
# ------------------------------------------------------------------------------
# Performance tiers only (low/mid/high) using cuda, vulkan, etc.
# No raw scores, no platform summary, no gpu=cuda.
# ------------------------------------------------------------------------------

import json
import xml.etree.ElementTree as ET
from pathlib import Path
import subprocess
import argparse
import re

LABEL_MAP = {
    "build-linux-kernel": "cpu",
    "vkmark":             "vulkan-perf",
    "unigine-heaven":     "opengl-perf",
    "octanebench":        "cuda-perf",
    "juliagpu":           "opencl-perf",
}

THRESHOLDS = {
    "cpu":         {"mid": 80, "high": 140},
    "vulkan-perf":  {"low": 20, "mid": 60},
    "opengl-perf":  {"low": 40, "mid": 100},
    "cuda-perf":    {"low": 20, "mid": 60},
    "opencl-perf":  {"low": 20, "mid": 60},
}

def classify(label, value):
    if label == "cpu":
        if value > THRESHOLDS[label]["high"]:
            return "high"
        elif value > THRESHOLDS[label]["mid"]:
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

def label_node(node, key, value):
    print(f"[kubectl] Labeling {node}: {key}={value}")
    subprocess.run(
        ["kubectl", "label", "node", node, f"{key}={value}", "--overwrite"],
        check=True
    )

def parse_results():
    results = {label: None for label in LABEL_MAP.values()}

    for xml in Path.home().glob(".phoronix-test-suite/test-results/*/composite.xml"):
        try:
            root = ET.parse(xml).getroot()
            test_id = root.findtext("Result/Identifier")
            if not test_id:
                continue
            short = test_id.split("/")[-1]
            base = short.rsplit("-", 1)[0]
            label = LABEL_MAP.get(base)
            if not label:
                continue
            value = float(root.findtext("Result/Data/Entry/Value"))
            results[label] = value
        except Exception as e:
            print(f"[!] Error parsing {xml}: {e}")
            continue
    return results

def has_battery():
    try:
        power_devices = subprocess.check_output(["upower", "-e"]).decode().splitlines()
        return any("battery" in device for device in power_devices)
    except Exception as e:
        print(f"[WARN] Battery detection failed: {e}")
        return False

def detect_storage_type():
    try:
        root_device = (
            subprocess.check_output(
                ["findmnt", "-n", "-o", "SOURCE", "/"]
            )
            .decode()
            .strip()
        )
        dev_name = Path(root_device).name

        if re.match(r".*p\d+$", dev_name):
            base = re.sub(r"p\d+$", "", dev_name)
        else:
            base = re.sub(r"\d+$", "", dev_name)

        if base.startswith("mmcblk"):
            return "sdcard"
        if dev_name.startswith("loop") or "vhd" in root_device.lower():
            return "virtual"
        rotational_path = Path(f"/sys/block/{base}/queue/rotational")
        if rotational_path.exists():
            with rotational_path.open() as f:
                return "ssd" if f.read().strip() == "0" else "hdd"
        return "unknown"

    except Exception as e:
        print(f"[WARN] Storage detection failed: {e}")
        return "unknown"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--node", required=True, help="Kubernetes node name")
    args = parser.parse_args()
    node = args.node
    results = parse_results()

    for label, value in results.items():
        if value is None:
            print(f"[WARN] No result for {label}")
            continue
        perf_class = classify(label, value)
        label_node(node, label, perf_class)

    has_batt = "true" if has_battery() else "false"
    label_node(node, "has-battery", has_batt)

    storage_type = detect_storage_type()
    label_node(node, "storage", storage_type)

if __name__ == "__main__":
    main()
