"""Rend les modules de migration importables.

Les dossiers `0N_etape/` sont préfixés d'un chiffre : ils ne sont pas des
packages importables par leur nom. Chacun est ajouté à `sys.path`, ce qui
reproduit le contrat d'import attendu de l'orchestrateur.
"""

import sys
from pathlib import Path

sys.path[:0] = [str(dossier) for dossier in sorted(Path(__file__).resolve().parent.parent.glob("0*_*"))]
