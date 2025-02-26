#!/usr/bin/python3

import os
import math
import json

print("Test ECMP")
print("Running iperf")
print("(might take a while)")

with open("topology.json") as f:
    topo_json = json.load(f)
topo = 0
links = topo_json["links"]
for l in links:
    if l["node1"] == "a1" and l["node2"] == "c1":
        if l["port1"] == 1 or l["port1"] == 2:
            topo = 1
    if l["node1"] == "c1" and l["node2"] == "a1":
        if l["port2"] == 1 or l["port2"] == 2:
            topo = 1

# Running a scripts to send iperf traffic for each host pair
# (hx->hy for any x and y from 1 to 16)
os.system(f"sudo ./test_scripts/iperf_send.sh {topo}")

fail = False
# Check each pod in the fattree
for pod in range(1, 5):
    # s1 and s2 are the id for the two aggregate swicthes in the pod
    s1 = (pod - 1) * 2 + 1
    s2 = (pod - 1) * 2 + 2
    d1 = 0
    d2 = 0
    d3 = 0
    d4 = 0
    # d1, d2, d3, d4 are the number of packets in the 4 links connected from the two
    # aggregated switches to the core switches; those 4 numbers should be balanced if
    # the ECMP works
    with open(f"tcpdump_logs/log{s1}_1.output", "r") as f:
        contents = f.read()
        d1 = len(contents)
    with open(f"tcpdump_logs/log{s1}_2.output", "r") as f:
        contents = f.read()
        d2 = len(contents)
    with open(f"tcpdump_logs/log{s2}_1.output", "r") as f:
        contents = f.read()
        d3 = len(contents)
    with open(f"tcpdump_logs/log{s2}_2.output", "r") as f:
        contents = f.read()
        d4 = len(contents)
    # Check whether the 4 numbers are balanced using the deviation
    avg = (d1 + d2 + d3 + d4) / 4.0
    if d1 == 0 or d2 == 0 or d3 == 0 or d4 == 0:
        fail = True
    dev = (
        (d1 - avg) * (d1 - avg)
        + (d2 - avg) * (d2 - avg)
        + (d3 - avg) * (d3 - avg)
        + (d4 - avg) * (d4 - avg)
    ) / 4.0
    dev = math.sqrt(dev) / avg
    print(f"Deviation: {dev:.3f}")
    if abs(dev) > 0.25:
        fail = True

if fail:
    print("Some deviation exceeds the 0.25 threshold.")
    print("Test fails. Your traffic is not evenly distributed.")
else:
    print("Test passes. Your traffic is evenly distributed on the paths.")
