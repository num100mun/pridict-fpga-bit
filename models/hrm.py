"""High‑level HRM model skeleton built on top of the graph encoder."""

from __future__ import annotations

from torch import nn

from dataio.graph_builder import GraphPack
from .gnn import GNNEncoder


class HRMModel(nn.Module):
    """Compose a :class:`GNNEncoder` with a simple linear prediction head."""

    def __init__(self, in_dim: int = 2, hidden_dim: int = 32, enc_dim: int = 64, out_dim: int = 1) -> None:
        super().__init__()
        self.encoder = GNNEncoder(in_dim=in_dim, hidden_dim=hidden_dim, out_dim=enc_dim)
        self.head = nn.Linear(enc_dim, out_dim)

    def forward(self, x, edge_index):
        h = self.encoder(x, edge_index)
        return self.head(h)

    def forward_pack(self, pack: GraphPack):
        data = GNNEncoder.from_graph_pack(pack)
        return self.forward(data.x, data.edge_index)

