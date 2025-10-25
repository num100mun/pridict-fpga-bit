"""Basic graph neural network encoder utilities.

The project currently relies on a simple :class:`GraphPack` container to
describe graphs.  This module implements a small GraphSAGE style encoder that
operates on tensors derived from that container.  The goal is to provide a
light‑weight yet functional architecture for experiments and HRM model
prototypes.
"""

from __future__ import annotations

from dataclasses import dataclass

import torch
from torch import nn

from dataio.graph_builder import GraphPack


@dataclass
class GraphData:
    """Tensors representing a graph suitable for the encoder."""

    x: torch.Tensor
    edge_index: torch.Tensor


class GraphSAGELayer(nn.Module):
    """A minimal implementation of the GraphSAGE update rule."""

    def __init__(self, in_channels: int, out_channels: int) -> None:
        super().__init__()
        self.linear = nn.Linear(in_channels * 2, out_channels)

    def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
        row, col = edge_index
        aggr = torch.zeros_like(x)
        aggr.index_add_(0, row, x[col])

        deg = torch.zeros(x.size(0), device=x.device)
        deg.index_add_(0, row, torch.ones_like(row, dtype=x.dtype))
        deg = deg.clamp(min=1).unsqueeze(-1)
        aggr = aggr / deg

        h = torch.cat([x, aggr], dim=-1)
        return torch.relu(self.linear(h))


class GNNEncoder(nn.Module):
    """Stack of :class:`GraphSAGELayer` blocks."""

    def __init__(self, in_dim: int = 2, hidden_dim: int = 32, out_dim: int = 64, layers: int = 2) -> None:
        super().__init__()
        gnn_layers = []
        for i in range(layers):
            inp = in_dim if i == 0 else hidden_dim
            out = out_dim if i == layers - 1 else hidden_dim
            gnn_layers.append(GraphSAGELayer(inp, out))
        self.layers = nn.ModuleList(gnn_layers)

    def forward(self, x: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
        for layer in self.layers:
            x = layer(x, edge_index)
        return x

    @staticmethod
    def from_graph_pack(pack: GraphPack) -> GraphData:
        """Convert a :class:`GraphPack` into tensors for the encoder."""

        x = torch.tensor([[n["x"], n["y"]] for n in pack.nodes["tile"]], dtype=torch.float)
        edge_index = torch.tensor(pack.edges, dtype=torch.long).t().contiguous() if pack.edges else torch.empty((2, 0), dtype=torch.long)
        return GraphData(x=x, edge_index=edge_index)

