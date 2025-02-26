/*
 * Summary: this module does L3 forwarding.
 * For more info on this module, read the project README.
 */

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "include/headers.p4"
#include "include/parsers.p4"

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
        // Dropped packets will not get forwarded
        mark_to_drop(standard_metadata);
    }

    // Set next hop
    // port: the egress port for this packet
    action set_nhop(egressSpec_t port) {
        // TODO: Define the set_nhop action
    }

    // ECMP Only
    // ecmp_group_id: ecmp group ID for this switch, specified by controller
    // num_nhops: the number of total output ports, specified by controller
    action ecmp_group(bit<14> ecmp_group_id, bit<16> num_nhops) {
        // TODO: define the ecmp_group action, where you need to hash the
        // 5-tuple mod num_ports and save it in metadata
    }

    // For Task 1, this table maps dstAddr to the set_nhop action (essentially
    // just mapping dstAddr to an output port). For ECMP, this table maps
    // dstAddr to either the set_nhop action or the ecmp_group action. The
    // action ecmp_group is actually calculating the hash value and kicking
    // off ecmp logic.
    table ipv4_lpm {
        // TODO: overwrite the following to define the IP forwarding table
        key = { }
        actions = {
            drop;
        }
        default_action = drop();
    }

    // ECMP Only
    // The second table maps the hash value you get (you probably need to think
    // of how to store the hash value calculated in the ecmp_group) and the
    // ecmp_group_id to the egress port. The action set_nhop sets the egress
    // port.
    table ecmp_group_to_nhop {
        // TODO: overwrite the following to define the ecmp table; this table is
        // only called when multiple egress ports are available
        key = { }
        actions = {
            drop;
        }
        default_action = drop();
    }

    apply {
        // TODO: implement the ingress logic.
        // Hint (ECMP Only): check validities, apply first table (i.e., ipv4_lpm),
        // and if multiple possible egress ports exist (i.e., ecmp_group action
        // triggered), then apply the second table (i.e., ecmp_group_to_nhop).
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
 *                    CHECKSUM COMPUTATION                               *
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
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
