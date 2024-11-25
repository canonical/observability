import unittest

from test_helpers import purge


class TestCommon(unittest.TestCase):
    def test_purge_removes_keys(self):
        structure = {
            "foo": "bar",
            "egress-subnets": "1.2.3.4/24",
            "ingress-address": "2.2.2.2",
            "private-address": "192.168.0.1",
        }
        purge(structure)
        assert structure == {"foo": "bar"}
