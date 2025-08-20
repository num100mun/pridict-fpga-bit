"""Utilities for loading data exported from Vivado.

This module parses simple CSV based dumps produced by the
``export_vivado_dataset.tcl`` script.  The exported directory is
expected to contain the following files:

``tiles.csv``
    Describes the tiles present in the design.  Columns:
    ``tile_name,tile_type,x,y``.

``pips.csv``
    Describes the routing PIPs available in each tile.  Columns:
    ``pip_name,tile_name`` (additional columns are ignored).

``bits.csv``
    Maps configuration bits to PIPs.  Columns:
    ``pip_name,bit_index,value``.

The information from these files is converted into a :class:`GraphPack`
object which stores nodes for tiles, pips and bits and edges describing
the relationship between them.  This structure can then be consumed by
GNN models.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Tuple
import csv


@dataclass
class GraphPack:
    """Container holding graph data.

    The structure is purposely very lightweight – it only records nodes of
    three different types (``tile``, ``pip`` and ``bit``) and the edges
    connecting them.  This mirrors the needs of the project and is kept
    intentionally simple so that it works even though the original
    ``GraphPack`` class in :mod:`graph_builder` is incomplete.
    """

    node_index: Dict[str, Dict[str, int]] = field(
        default_factory=lambda: {"tile": {}, "pip": {}, "bit": {}}
    )
    nodes: Dict[str, List[dict]] = field(
        default_factory=lambda: {"tile": [], "pip": [], "bit": []}
    )
    edges: List[Tuple[int, int, str]] = field(default_factory=list)
    labels: Dict[int, int] = field(default_factory=dict)

    # ------------------------------------------------------------------
    # Node helpers
    def add_tile(self, name: str, tile_type: str, x: int, y: int) -> int:
        idx = len(self.nodes["tile"])
        self.node_index["tile"][name] = idx
        self.nodes["tile"].append({"name": name, "type": tile_type, "x": int(x), "y": int(y)})
        return idx

    def add_pip(self, name: str, tile: str) -> int:
        idx = len(self.nodes["pip"])
        self.node_index["pip"][name] = idx
        self.nodes["pip"].append({"name": name, "tile": tile})
        tile_idx = self.node_index["tile"].get(tile)
        if tile_idx is not None:
            self.edges.append((tile_idx, idx, "tile2pip"))
        return idx

    def add_bit(self, pip: str, bit_index: int, value: int) -> int:
        idx = len(self.nodes["bit"])
        bit_name = f"{pip}:{bit_index}"
        self.node_index["bit"][bit_name] = idx
        self.nodes["bit"].append({"name": bit_name, "pip": pip, "index": int(bit_index), "value": int(value)})
        pip_idx = self.node_index["pip"].get(pip)
        if pip_idx is not None:
            self.edges.append((pip_idx, idx, "pip2bit"))
        return idx


# ---------------------------------------------------------------------------
# CSV parsing helpers

def _read_csv(path: Path) -> Iterator[Dict[str, str]]:
    """Yield rows from a CSV file as dictionaries.

    The function strips whitespace from both keys and values so that the
    loader is tolerant to minor formatting issues.
    """

    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            yield {k.strip(): (v.strip() if isinstance(v, str) else v) for k, v in row.items()}


# ---------------------------------------------------------------------------
# Public API

def load_vivado_export(directory: str | Path) -> GraphPack:
    """Load a Vivado export directory into a :class:`GraphPack`.

    Parameters
    ----------
    directory:
        Path to the directory containing the CSV files produced by the
        export script.

    Returns
    -------
    GraphPack
        The populated graph structure.  Missing CSV files are silently
        ignored which allows partial datasets to be loaded.
    """

    base = Path(directory)
    gp = GraphPack()

    tiles_csv = base / "tiles.csv"
    if tiles_csv.exists():
        for row in _read_csv(tiles_csv):
            gp.add_tile(
                row.get("tile_name", ""),
                row.get("tile_type", ""),
                int(row.get("x", 0)),
                int(row.get("y", 0)),
            )

    pips_csv = base / "pips.csv"
    if pips_csv.exists():
        for row in _read_csv(pips_csv):
            gp.add_pip(row.get("pip_name", ""), row.get("tile_name", ""))

    bits_csv = base / "bits.csv"
    if bits_csv.exists():
        for row in _read_csv(bits_csv):
            gp.add_bit(
                row.get("pip_name", ""),
                int(row.get("bit_index", 0)),
                int(row.get("value", 0)),
            )

    return gp


__all__ = ["GraphPack", "load_vivado_export"]
