/*
 * Summary: This module does layer 2 forwarding on packets.
 * Layer 2 forwarding uses the packet's MAC address to forward it to an egress port.
 */

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
 *                              HEADERS                                  *
 *************************************************************************/

// Define ethernet header, metadata, and headers struct
typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

struct metadata {
    /* empty */
}

struct headers {
    ethernet_t ethernet;
}

/*************************************************************************
 *                              PARSER                                   *
 *************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        // Parse ethernet header
        packet.extract(hdr.ethernet);
        transition accept;
    }
}

/*************************************************************************
 *                     CHECKSUM VERIFICATION                             *
 *************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 *                     INGRESS PROCESSING                                *
 *************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }

    // Action to forward packets
    action forward(bit<9> egress_port) {
        standard_metadata.egress_spec = egress_port;
    }

    // Define a table for DMAC lookup
    table dmac {
        key = {
            hdr.ethernet.dstAddr: exact;
        }

        actions = {
            forward;
            drop;
            NoAction;
        }
        size = 256;
        default_action = NoAction;
    }

    apply {
        // Call the table
        dmac.apply();
    }
}

/*************************************************************************
 *                     EGRESS PROCESSING                                 *
 *************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *                     CHECKSUM COMPUTATION                              *
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 *                              DE-PARSER                                *
 *************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // Deparse the ethernet header
        packet.emit(hdr.ethernet);
    }
}

/*************************************************************************
 *                              SWITCH                                   *
 *************************************************************************/

// Switch architecture
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
