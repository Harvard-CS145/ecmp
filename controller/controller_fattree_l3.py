#!/usr/bin/python3

# ./controller/controller_fattree_l3.py
#   Insert P4 table entries to route traffic among hosts for FatTree topology
#   under L3 routing

from p4utils.utils.helper import load_topo
from p4utils.utils.sswitch_thrift_API import SimpleSwitchThriftAPI


class RoutingController:

    def __init__(self):
        self.topo = load_topo("topology.json")
        self.controllers = {}
        self.init()

    def init(self):
        self.connect_to_switches()
        self.reset_states()
        self.set_table_defaults()

    def connect_to_switches(self):
        for p4switch in self.topo.get_p4switches():
            thrift_port = self.topo.get_thrift_port(p4switch)
            self.controllers[p4switch] = SimpleSwitchThriftAPI(thrift_port)

    def reset_states(self):
        [controller.reset_state() for controller in self.controllers.values()]

    def set_table_defaults(self):
        # TODO: define table default actions
        pass

    def route(self):
        # TODO: define routing algorithm
        pass

    def main(self):
        self.route()


if __name__ == "__main__":
    RoutingController().main()
