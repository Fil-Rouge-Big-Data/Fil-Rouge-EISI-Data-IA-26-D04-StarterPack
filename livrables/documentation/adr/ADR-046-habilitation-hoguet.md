# ADR-046 — Habilitation : carte T ou attestation (loi Hoguet)

> **Statut :** Accepté · **Date :** 2026-10-06 · **Déclencheur :** revue v8 (sonde S10). · **Source :** DGCCRF, « L'agent immobilier : les règles qui encadrent la profession » (economie.gouv.fr/dgccrf).

## 1. Contexte

La v8 imposait à chaque chasseur une `numero_carte_t` **unique et obligatoire**.
C'est faux au regard de la loi Hoguet (vérifié, source DGCCRF) :

- La **carte professionnelle (carte T)** est délivrée par la **CCI** au
  **titulaire** de l'agence (depuis 2015 ; auparavant la préfecture).
- Les **négociateurs** (salariés ou agents commerciaux) habilités à négocier pour
  le compte du titulaire ne détiennent pas la carte T : ils justifient de leur
  qualité par une **attestation d'habilitation**, délivrée par le titulaire et
  visée par la CCI.

Donc plusieurs chasseurs d'une même agence relèvent de la **même** carte T (pas
d'unicité par chasseur), et la plupart n'ont **pas** de carte T mais une
attestation.

## 2. Décision

Modèle **minimal** sur `chasseur` (pas de table agence à ce stade) :

- `type_habilitation` : `'carte_t'` ou `'attestation'`.
- `numero_habilitation` : numéro de carte T ou d'attestation, **non unique**.
- `date_validite_habilitation` : l'exigence métier est « carte T **ou**
  attestation **en cours de validité** ».
- `organisme_delivrance` : CCI (ex-préfecture).
- Contrainte `ck_chasseur_habilitation` : un **salarié** ne peut pas détenir la
  carte T en propre → `type_habilitation = 'attestation'`.

Le **gel** de l'habilitation à la signature du mandat
(`numero_habilitation_signature`, `validite_habilitation_signature`, ADR-039) suit
ce modèle, et devient nullable à la reprise (ADR-045 §2.5).

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| `numero_carte_t` unique par chasseur (v8) | Contraire à la loi Hoguet : la carte est au titulaire, partagée par les collaborateurs. |
| Table `agence` + `habilitation` nominative (modèle complet) | Plus juste mais lourd ; pas d'entité agence dans le modèle actuel. Reporté si un besoin le démontre. |

## 4. Conséquences

- **Positives :** modèle conforme au droit ; sonde S10 fermée ; migration des
  chasseurs repris en `attestation` (cohérent avec « salarié »).
- **Limite :** le lien explicite chasseur→carte T du titulaire n'est pas
  modélisé (modèle minimal). À rouvrir si la gestion multi-agences l'exige.
- **Point de validité à noter :** une attestation expire à la fin du contrat ou,
  au plus tard, à l'échéance de la carte T du titulaire ; au renouvellement de la
  carte, les attestations des collaborateurs doivent être renouvelées. Non géré
  par le modèle minimal (backlog).

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Conformité réglementaire dans le modèle, sourcée |
| BC03 | Contrainte métier portée par le schéma |
