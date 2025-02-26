/*
 * Summary: The following section defines logic required to parse a packet's
 * headers. Packets need to be parsed in the same order they are added to a
 * packet. See headers.p4 to see header declarations. Deparsing can be
 * thought of as stitching the headers back into the packet before it leaves
 * the switch. Headers need to be deparsed in the same order they were parsed.
 */

/*************************************************************************
 *                              PARSER                                   *
 *************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        // TODO: Define a parser for ethernet, ipv4 and tcp
    }
}

/*************************************************************************
 *                             DE-PARSER                                 *
 *************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // TODO: Deparse the ethernet, ipv4 and tcp headers
    }
}
