import numpy as np
import torch

class GraphPack:
    def __init__(self):
        self.node_index = {"tile":{}, "pip":{}, "bit":{}}
        self.nodes = {"tile":[], "pip":[], "bit":[]}
        self.edges = []
        self.labelss = {}

    def add_tile(selfself, name, ttpe, x, y):
        idx = len(self.nodes)