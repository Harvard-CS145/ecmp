#!/usr/bin/python3

import os


def test_fat_tree():
    print("Testing l3 fwd")

    print("Controller Unit Tests")
    # Get all hostnames and their IP addresses
    host_ips = []
    hosts = []
    for i in range(1, 17):
        hosts += [f"h{i}"]
        host_ips += [f"10.0.0.{i}"]

    print("Unit Test: Ping mesh")
    print("(might take a while)")
    # Try to use pingall to test whether network get connected after changing to L3 fwd
    c = 0
    for h in hosts:
        for ip in host_ips:
            assert (
                ", 0% packet loss"
                in os.popen(f"mx {h} ping -c 1 {ip}").read()
            ), "Expected pingall 0% packet loss"
            c += 1
            print(int(c * 100.0 / (16 * 16)), "% complete.", end="\r", flush=True)

    print()
    print("Test passed")


if __name__ == "__main__":
    test_fat_tree()
