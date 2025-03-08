# Project 3: ECMP and Application Placement

## Objectives

* ECMP is the most commonly used forwarding strategy in modern data centers. In this section, we will implement ECMP and understand its benefits.
* We will also learn how to use P4 language to program switches.
* Understand the benefit of FatTree on application placement.

## Getting Started

To start this project, you will first need to get the [infrastructure setup](https://github.com/minlanyu/cs145-site/blob/spring2025/infra.md) and clone this repository with submodules:

```bash
git clone --recurse-submodules "<your repository>"
```

When there are updates to the starter code, TFs will open pull requests in your repository. You should merge the pull request and pull the changes back to local. You might need to resolve conflicts manually (either when merging PR in remote or pulling back to local). However, most of the times there shouldn't be too much conflict as long as you do not make changes to test scripts, infrastructures, etc. Reach out to TF if it is hard to merge.

In Project 1, we distributed traffic across two separated core switches for different application (`controller_fattree_twocore.py`). But this is not efficient enough. For instance, if one application stops working, then its corresponding core switch is wasted. Or if we have many applications, we may not afford to have one core per application. Thus, we need a more advanced routing strategy -- ECMP. At the end of ECMP experiment, you are expected to see even higher throughput of iperf and lower latency of Memcached, compared with `controller_fattree_twocore.py`.

In this project, we only focus on the FatTree topology with k=4 (i.e., 16 hosts) and BinaryTree with 16 hosts. You will implement Layer-3 routing and ECMP by modifying `p4src/l3fwd.p4` for the data plane and `controller_fattree_l3.py` for the control plane. We provide a [detailed explanation on P4](p4_explanation.md) which include most useful concepts and primitives about P4 in this project and future projects.

## Task 1: Switching To Layer-3 Routing

Your first task is to switch layer-2 routing based on MAC addresses (in `l2fwd.p4`) to layer-3 routing based on IP addresses. Layer 3 routing (also called Network layer routing or IP routing) uses IP addresses to compute routes and configure forwarding tables. Instead of looking at the MAC address, the match action tables on the switch use the IP addresses as their key. Note that the default IP addresses for the 16 hosts are from 10.0.0.1 to 10.0.0.16.

Start by copying your solution to `topology/generate_fattree_topo.py` from Project 1 to Project 3. Change the `p4_src` in the template to point to `p4src/l3fwd.p4`:

```diff
-    "p4_src": "p4src/l2fwd.p4",
+    "p4_src": "p4src/l3fwd.p4",
```

The generate the FatTree topology with k=4 the same as in Project 1:

```bash
./topology/generate_fattree_topo.py 4
```

These would need to be done only once. The rest of this project will then rely on the generated topology file `topology/p4app_fattree.json`.

### Step 1: Handling Layer 3 Packets

- Define a parser for `tcp` packets (`MyParser` in `p4src/include/parsers.p4`).
- Define the deparser by calling `emit` on all headers (`MyDeparser` in `p4src/include/parsers.p4`).
- Define the ingress processing logic, including a table with destination IP address as the key, and corresponding actions (`MyIngress` in `p4src/l3fwd.p4`).

**Hint 1:** To correctly set up a parser for TCP packets, you first need to extract the headers for Ethernet and IP, because TCP is a protocol that is layered within the data of the Ethernet and IP protocols.

**Hint 2:** You should consider using lpm (longest prefix matching) rather than exact matching mechanism to reduce the number of table entries. lpm enables you to use subnet as the matching key. For example, subnet 10.0.1.0/24 represents all IP addresses matching the first 24 bits of 10.0.1.0, i.e., IP addresses from 10.0.1.0 to 10.0.1.255. Note that if you want to set a single IP address, e.g., 10.0.1.1 as the key of a lpm table key, you still need to specify the prefix length in the key by using 10.0.1.1/32 instead of 10.0.1.1. lpm means that when there are multiple rules that matches the incoming packet, we follow the rule with the longest prefixes (i.e., the subnet with the longest length. e.g., /32 > /24).

### Step 2: Set up the forwarding table

In `controller/controller_fattree_l3.py`, fill up the rules in the forwarding table. In Project 1, we did L2 forwarding in the controller:

```python
controller.table_add("dmac", "forward", [f"00:00:0a:00:00:{host_id + 1:02x}"], [f"{out_port}"])
```

Now, we change it to L3 forwarding:

```python
controller.table_add("ipv4_lpm", "set_nhop", [f"10.0.0.{host_id + 1:d}/32"], [f"{out_port}"])
```

### Test your code

Start Mininet and the controller:

```bash
sudo p4run --config topology/p4app_fattree.json
./controller/controller_fattree_l3.py
```

Run our testing script:

```bash
sudo ./test_scripts/validate_task1.py
```

## Task 2: Implement ECMP

To implement ECMP, we need to first write P4 code in the data plane to define the tables and then write a controller which installs forwarding rules in the tables. Here are a few high-level guidelines:

### Step 1: Implement ECMP tables in the data plane

In `p4src/l3fwd.p4`, implement the ECMP tables in the ingress part of the switch and define necessary metadata fields. This is in addition to the L3 forwarding logic you added in Task 1. At a high level, instead of specifying an output port for each flow, we now specify an output port groups for a group of flows.

There are two types of flows at a switch: (1) Downward flows: For those flows that go downward in the FatTree, there is only one downward path to each destination. That is, there is one output port for these flows. (2) Upward flows: For those flows that go to the upper layers of the FatTree, there are multiple equal-cost paths. So we create an ECMP group for these output ports, and use a hash function to decide which output port to send each flow based on its five tuples (i.e., source IP address, destination IP address, source port, destination port, protocol).

In `l3fwd.p4`, you need to define two tables: `ipv4_lpm` and `ecmp_group_to_nhop`.

First, the `ipv4_lpm` table is similar to Task 1 that selects output ports for downward flows, but triggers the action `ecmp_group` for upward flows to calculate hash value. We can calculate the hash function based on the five tuples of a flow, and store the hash value in the metadata for the next table to use.

Second, the `ecmp_group_to_nhop` table maps on the hash value to decide which egress port to send the packet. Note that we need two tables here because we only need the hash calculation for packets that go upper layers. Therefore, we need the first table to match on packet IP addresses and the second table to match on hash values.

One problem is that since both ToR and Aggregate switches hash on the same five tuples, they may make the same decision on which output port number to take. This causes a collision problem: If two flows get the same hash values on the ToR switch, they also get the same hash values on the aggregate switch. (*Think: why is this a problem?*)

To solve this problem, one idea is to use different hash seeds for the ToR and aggregate switches. However, we would like the P4 code in the data plane to be **topology independent**. That is, we cannot allocate hash seeds based on the switch locations, host IP addresses or the paths in the topology.

To solve the problem, we introduce the `ecmp_group_id`. We set all ToR switches with one specific `ecmp_group_id`, while all aggregated switches with another ID. We can then specify different rules in the `ecmp_group_to_nhop` table based on both the hash value and the `ecmp_group_id`.

### Step 2: Generate rules at the controller

In `controller/controller_fattree_l3.py`, you need to generate rules for the tables. This is in addition to the l3 routing logic you added in Task 1.

The controller pre-installs rules in the forwarding tables at switches that forward packets based on the hash values and `ecmp_group_id`'s. The controller should set different `ecmp_group_id`'s for ToR and Aggregate switches. You may check [P4 explanation](p4_explanation.md) on how to write match-action rules in controller.

The controller can assume the default IP addresses for the 16 hosts are from 10.0.0.1 to 10.0.0.16. The controller can also differentiate ToR, Core, Aggregate switches by their names, and install different rules for each type of switches.

The rules for each type of switches should be independent, but the rules together should deliver the packets via all the available shortest paths.

### Test your code

We have a testing script `test_scripts/validate_task2.py`, which monitors the traffic in your network, to validate whether ECMP works. It generates iperf traffic randomly, and tests whether the load is balanced across different hops.

Start Mininet and the controller:

```bash
sudo p4run --config topology/p4app_fattree.json
./controller/controller_fattree_l3.py
```

Run our testing script:

```bash
sudo ./test_scripts/validate_task2.py
```

## Performance comparison for ECMP (for k=4 FatTree)

Now we have successufully implemented ECMP in our network, we would like to compare its performance with prior routing solutions: two-core splitting and the BinaryTree (in Project 1).

**Expr 3-1:** Run the same traffic trace as Project 1 (`./apps/trace/project1.trace` generated based on `apps/trace/project1.json`) on FatTree topology using ECMP. First start Mininet and then run script `expr3-1.sh` (which calls the controller and runs the traffic trace 5 times for you) and record the average `iperf` throughput and `memcached` latency of each trace execution. This is exactly the same as what we did in Project 1.

```bash
sudo p4run --config topology/p4app_fattree.json
./test_scripts/expr3-1.sh
```

> [!NOTE]
> The numbers can vary from time to time. It is better to run the experiments for at least 5 times to see the difference between different versions.

### Questions

You should answer the following questions in your `report/report.md`:

* What is the average throughput of iperf and average latency of memcached you observe for ECMP?
* How do you compare them with the BinaryTree (Expr 1-3) and two-core splitting (Expr 1-2)?
* Explain why you see the differences. Use measurement results to demonstrate your points.

**Hint 1:** To understand the performance difference, the first step is to verify that you are using all four cores. The next step is to track the paths the memcached and iperf traffic take. If they collide on the same path, it will cause congestion and affect performance.

**Hint 2:** The paths taken by the traffic may be related to the hash values. If the paths collide, try changing the hash seeds and see if the paths change.

**Hint 3:** Depending on your machine settings, one problem may be that ECMP introduces more packet processing and takes more CPU resources in the simulation, which may affect the ECMP performance. You should stop the other irrelvant applications in your machine during your experiments. If you still have problems, you may consider running the experiment on Amazon EC2. See how to set it up in `infra.md`.

## Bisection Bandwidth

In this experiment, you will measure the bisection bandwidth of BinaryTree topology and FatTree topology. Here we are using UDP traffic instead of TCP traffic, because TCP traffic takes a long time to converge, and the traffic rate before the convergence is not accurate.

> [!NOTE]
> You need to define the UDP header and parse the UDP header in the parser, and UDP packets have different `hdr.ipv4.protocol` value compared with TCP packets. Start by adding the following to `p4src/include/headers.p4` and updating the `headers` struct. Then update the parser and deparser in `p4src/include/parsers.p4` to handle UDP packets.
>
> ```
> header udp_t {
>     bit<16> srcPort;
>     bit<16> dstPort;
>     bit<16> len;
>     bit<16> checksum;
> }
> ```

You need to run 8 iperf flows between 8 pairs of senders and receivers. We provide you with two different flow mappings between iperf clients and iperf servers.

- BinaryTree: Go to your Project 1 repository, follow its instructions to generate BinaryTree topology with `I=4`, start mininet with that topology, and run the BinaryTree controller with `I=4`.
- FatTree (ECMP): Directly in this repository, you should have already generated FatTree topology with `k=4`, then start mininet and run the ECMP controller.

In each case, you can then use the following commands to generate traffic trace and send traffic.

```bash
# h1 <-> h9  h2 <-> h10  h3 <-> h11  ...  h8 <-> h16
./apps/trace/generate_trace.py ./apps/trace/project3_bisec1.json
sudo ./apps/send_traffic.py --trace apps/trace/project3_bisec1.trace --protocol udp
```

```bash
# h1 <-> h5   h2  <-> h6   h3  <-> h7   h4  <-> h8
# h9 <-> h13  h10 <-> h14  h11 <-> h15  h12 <-> h16
./apps/trace/generate_trace.py ./apps/trace/project3_bisec2.json
sudo ./apps/send_traffic.py --trace apps/trace/project3_bisec2.trace --protocol udp
```

Each command will start one `iperf` on each host, and let 8 of them send traffic to the remaining 8 in a one-to-one mapping manner. The output of those iperf servers and clients will be stored in the `logs/` directory, and you can also see the average throughput of iperf once the `send_traffic.py` script completes.

### Questions

You should answer the following questions in your `report/report.md`:

* What is the bisection bandwidth in theory for FatTree?
* What average throughput do you get from `bisec1` and `bisec2` traces under FatTree?
* What average throughput do you get from `bisec1` and `bisec2` traces under BinaryTree?
* What's the throughput difference for `bisec1` between FatTree and BinaryTree? Why one is better than the other?
* What's the throughput difference for `bisec1` between the theory result and the FatTree? Why one is better than the other?

## Application placement in FatTree

In this experiment, you will place the iperf and Memcached applications in different hosts and see how placement affects their performance under different topologies.

You will test application placements as follows:

* Placement setting 1: two iperf flows (h1 <-> h3) (h2 <-> h4) + Memcached on h5,h6,h7,h8
* Placement setting 2: two iperf flows (h1 <-> h5) (h3 <-> h7) + Memcached on h2,h4,h6,h8

Their traces can be respectively generated by:

```bash
# Placement setting 1: ./apps/trace/project3_app1.trace
./apps/trace/generate_trace.py ./apps/trace/project3_app1.json
# Placement setting 2: ./apps/trace/project3_app2.trace
./apps/trace/generate_trace.py ./apps/trace/project3_app2.json
```

The above application placements are just a suggestion. The application placement that helps your particular ECMP implementation depends on the way you hash your flows. You need to find an application placement that makes sense for your implementation and impacts its performance. Mention your chosen application placement in your report.

> [!NOTE]
> Different placement forwards iperf flows and Memcached flows in different paths. If different flow paths overlap a lot, then the performance should be poorer. Instead, if those paths do not overlap a lot, then the performance should be better. Therefore, you can find two different placements based on the flow paths with different performance.

You will run your chosen placement(s) on the FatTree topology.

### Questions

You should answer the following question in your `report/report.md`:

* Does the average throughput of iperf change under FatTree with different placement schemes? Why?

## Extra Credits

### Optional Task 1 (20 credits)

Can you try to design a different topology other than BinaryTree and FatTree by following two constraints: (1) the total bandwidth of links for one switch do not exceed the switch capacity, (2) the number of links for one switch cannot exceed four? But you can use any number of switches. You should also define your own routing schemes on your topology. How do you compare its performance with BinaryTree and FatTree? Please describe your design in your `report/report.md`.

### Optional Task 2 (25 credits)

Can you try to extend the ECMP implementation to WCMP? We will discuss WCMP in class later. You can look up the key idea in [this Eurosys'14 paper](https://research.google/pubs/pub49093/).

The key difference between WCMP and ECMP is that it sets up weights for each outgoing ports rather than equally splitting packets across paths. There are three subtasks:

- Implement WCMP (10 credits)
- Generate testing cases that demonstrate the weighted splitting (5 credits)
- Design and implement scenarios to show the benefits of weighted splitting over ECMP (10 credits).

## Submission and Grading

### Submit your work

You are expected to tag the version you would like us to grade on using following commands and push it to your own repo. You can learn from [this tutorial](https://git-scm.com/book/en/v2/Git-Basics-Tagging) on how to use git tag command. This command will record the time of your submission for our grading purpose.

```bash
git tag -a submission -m "Final Submission"
git push --tags
```

### What to submit

You are expected to submit the following documents:

1. Code: The P4 programs that you write to implement L3 routing and ECMP in the dataplane (`p4src/l3fwd.p4`, `p4src/include/parsers.p4` and `p4src/include/headers.p4`). The controller programs that fill in the forwarding rules for FatTree topologies with L3 routing and ECMP (`controller/controller_fattree_l3.py`). Please also add brief comments that help us understand your code.
2. `report/report.md`: In this report, you should describe how you implement L3 routing, ECMP, and fill in rules with the controller. You also need to answer the questions above. You might put some figures in the `report/` folder, and embed them in your `report/report.md`.

### Grading

The total grades is 100:

- 20: Correctness of your solutions for L3 routing
- 40: Correctness of your solutions for ECMP forwarding schemes
- 40: For your answers to the questions in `report/report.md` (you may include some figures or screenshots if needed)
- Extra credits as described above
- Deductions based on late policies

## Survey

Please fill up the survey when you finish your project: [Survey link](https://forms.gle/B5edXkQW2xFJUjFq8).

> [!WARNING]
> Remember to regularly clean up your `log/` and `pcap/` folder. They will keep growing in size and may end up taking up all disk space available in the VM and lead to a crash.
