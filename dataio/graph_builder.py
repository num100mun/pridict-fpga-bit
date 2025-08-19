"""Utility helpers for building simple graph structures.

Currently the project uses a minimal :class:`GraphPack` container to keep
track of nodes and edges that will later be consumed by the models.  The
original implementation in this repository was a rough draft copied from an
interactive session and contained several typographical mistakes (such as the
`add_tile` method being declared with ``selfself`` and `ttpe`).  In addition,
the method did not actually store any information about the tile and the class
attribute holding labels was misspelled as ``labelss``.

Although the surrounding project is still a skeleton, fixing these issues makes
the helper usable and prevents runtime errors when the method is invoked.
"""

from __future__ import annotations

from typing import Dict, List, Any


class GraphPack:
    """A small container for heterogeneous graph components."""

    def __init__(self) -> None:
        # Map of node type -> mapping from node name to index
        self.node_index: Dict[str, Dict[str, int]] = {"tile": {}, "pip": {}, "bit": {}}
        # Map of node type -> list of node dictionaries
        self.nodes: Dict[str, List[Dict[str, Any]]] = {"tile": [], "pip": [], "bit": []}
        self.edges: List[tuple[int, int]] = []
        self.labels: Dict[str, Any] = {}

    def add_tile(self, name: str, type_: str, x: int, y: int) -> int:
        """Add a tile node to the graph.

        Parameters
        ----------
        name: str
            Identifier of the tile.
        type_: str
            Type of tile (e.g. logic, dsp, etc.).
        x, y: int
            Coordinates of the tile in the grid.

        Returns
        -------
        int
            Index of the newly inserted tile node.
        """

        idx = len(self.nodes["tile"])
        self.node_index["tile"][name] = idx
        self.nodes["tile"].append({"name": name, "type": type_, "x": x, "y": y})
        return idx
