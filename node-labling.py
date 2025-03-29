# Author: Delane Brandy
# Description: Dynamic performance labling of nodes in a hcn cluster

import json
import xml.etree.ElementTree as ET
from pathlib import Path

LABEL_MAP = {
    "build-linux-kernel": "cpu",
    "vkmark": "gpu-vulkan",
    "unigine-heaven": "gpu-opengl",
    "octanebench": "gpu-cuda",
    "juliagpu": "gpu-opencl",
}

results = {label: None for label in LABEL_MAP.values()}  # Initialize with nulls

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

    except Exception as e:
        print(f"[!] Error parsing {xml}: {e}")
        continue

output = {
    "node-performance": [results]
}

with open("node_performance.json", "w") as f:
    json.dump(output, f, indent=2)

print("[✓] node_performance.json written")
