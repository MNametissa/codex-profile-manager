# Codex Profile Manager

## Planning Summary

Objectif: concevoir un gestionnaire de profils Codex permettant a plusieurs comptes et plusieurs profils de configuration de travailler sur un meme projet sans perte d'historique, sans casser la continuite de contexte, et sans melanger les identites de connexion.

Le point de conception central est le suivant: pour Codex, l'historique de reference ne doit pas appartenir au compte actif. Il doit appartenir au projet, avec une journalisation des passages de relais entre profils. Le compte ne doit etre qu'un executant interchangeable.

## Scope

Le produit couvre:
- gestion de plusieurs comptes Codex sur une meme machine
- gestion de profils de configuration par compte
- bascule rapide entre comptes et profils
- reprise continue d'un meme projet par plusieurs profils
- suivi d'etat: auth, disponibilite, derniere activite, limite d'usage estimee
- export local des metadonnees de projet et de la chronologie inter-profils

Le produit ne couvre pas en V1:
- synchronisation cloud entre plusieurs machines
- fusion automatique de contextes internes proprietaires du CLI si leur format n'est pas stable
- prediction exacte de l'abonnement ou du quota si Codex n'expose pas ce signal de facon officielle

## Problem Statement

Aujourd'hui, les outils de type profile manager associent souvent historique, configuration et authentification au meme dossier. Ce modele fonctionne pour un CLI qui supporte un repertoire de config par session. Pour Codex, ce n'est pas suffisant.

Le besoin principal est operationnel:
- un projet doit pouvoir commencer avec un compte
- continuer avec un second compte quand le premier est limite
- reprendre plus tard avec un troisieme compte
- conserver un fil d'activite coherent, consultable et transmissible

La vraie unite de continuite est donc le projet, pas le compte.

## Product Principles

1. Un projet = une chronologie canonique.
2. Un compte = une identite d'execution interchangeable.
3. Un profil = une variante de configuration, pas une source d'historique.
4. Aucun changement de compte ne doit faire perdre la trace des sessions precedentes.
5. Le systeme doit preferer la continute observable a la magie fragile.

## Core User Stories

1. En tant qu'utilisateur, je peux enregistrer plusieurs comptes Codex et leur donner un nom clair: `perso`, `client-a`, `backup`.
2. En tant qu'utilisateur, je peux associer plusieurs profils de configuration a un meme compte: `fast`, `review`, `safe`.
3. En tant qu'utilisateur, je peux ouvrir un projet, voir quel compte l'a traite en dernier, puis reprendre avec un autre compte sans perdre le journal du projet.
4. En tant qu'utilisateur, je peux voir qu'un compte est potentiellement limite et choisir le prochain compte disponible.
5. En tant qu'utilisateur, je peux auditer la chronologie d'un projet: qui a travaille, quand, sur quelle branche, avec quel profil, et pourquoi le relais a eu lieu.

## Architecture Decision

Le systeme doit separer 3 couches:

### 1. Account Store

Stocke par compte:
- identifiant logique du compte
- mode d'authentification
- emplacements de config et d'auth isoles
- etat local connu: dernier refresh, dernier usage, statut estime

### 2. Project Ledger

Chaque projet gere par le manager recoit un dossier de metadonnees dedie, par exemple:

```text
~/.codex-manager/projects/<project-id>/
  project.toml
  activity.jsonl
  handoffs.jsonl
  notes/
  snapshots/
```

Ce dossier est la source de verite pour la continuite.

### 3. Runtime Adapter

Le runtime selectionne:
- un compte
- un profil de configuration Codex
- un repertoire projet

Puis il enregistre dans le ledger:
- le debut de session
- la fin de session
- le motif de handoff
- les metadonnees utiles de reprise

## Canonical History Model

Exigence principale: plusieurs profils doivent travailler sur un meme projet en continu, sans perte d'historique.

Decision:
- l'historique canonique est un journal externe au runtime natif de Codex
- chaque session Codex conserve son historique natif si disponible
- le manager construit un historique transverse du projet qui reference les sessions natives

Chaque entree `activity.jsonl` doit contenir au minimum:
- `timestamp`
- `project_id`
- `account_id`
- `config_profile`
- `session_id`
- `cwd`
- `git_branch`
- `git_commit_head`
- `event_type`
- `summary`

Chaque handoff entre profils doit produire une entree dans `handoffs.jsonl`:
- `from_account_id`
- `to_account_id`
- `from_session_id`
- `reason`
- `resume_instructions`
- `open_risks`
- `expected_next_step`

## Continuity Flow

Flux nominal:

1. L'utilisateur lance `codex-manager run --account perso --profile review`.
2. Le manager ouvre la session et cree une entree `session_started`.
3. Pendant ou apres la session, il capture les metadonnees observables.
4. Si le compte devient indisponible ou si l'utilisateur veut relayer, il lance `codex-manager handoff --to backup`.
5. Le manager genere une note de reprise structuree.
6. Le compte `backup` reprend le meme projet.
7. Le ledger relie les deux sessions dans une meme chronologie.

Le point critique: la reprise ne depend pas d'un format interne opaque. Elle depend d'un protocole de handoff maitrise par le manager.

## Handoff Protocol

Le systeme doit imposer un format minimal de relais:
- resume court de l'etat actuel
- travaux faits
- travaux en cours
- blockers
- fichiers touches
- commandes a relancer
- decision pending

Ce protocole doit etre genere en fichier local et reference dans `handoffs.jsonl`.

## Account and Profile Model

Un compte ne doit pas etre confondu avec un profil de config.

Modele cible:
- `account`: identite de connexion Codex
- `config_profile`: profil natif Codex ou equivalent logique
- `project_assignment`: dernier couple `account + profile` utilise sur un projet

Commande cible:

```text
codex-manager accounts list
codex-manager projects status
codex-manager run --account perso --profile review
codex-manager handoff --project <id> --to-account backup --to-profile fast
codex-manager history --project <id>
codex-manager next
```

## Milestones

1. Spec and storage foundation
Acceptance criteria:
- structure des dossiers definie
- schema du ledger defini
- protocole de handoff defini

2. Account isolation and switching
Acceptance criteria:
- plusieurs comptes enregistrables
- bascule de compte fiable
- statut local consultable

3. Shared project continuity
Acceptance criteria:
- un meme projet peut etre repris par plusieurs comptes
- chaque session apparait dans la chronologie du projet
- un handoff produit des instructions de reprise explicites

4. Availability and usage heuristics
Acceptance criteria:
- vue `next` ou `status` disponible
- estimation du compte le plus pertinent pour reprendre
- signal d'incertitude explicite si l'etat n'est qu'infere

## Risks and Mitigations

- Risque: Codex ne fournit pas d'API stable pour isoler auth et config par compte.
Mitigation: concevoir une couche d'isolation explicite et tester sur stockage local reel avant toute promesse UX.

- Risque: les signaux de limite d'usage ne sont pas officiels ou stables.
Mitigation: afficher "estime" et journaliser les evenements observables au lieu d'affirmer un quota exact.

- Risque: l'utilisateur pense retrouver le contexte natif complet alors que seul le ledger est garanti.
Mitigation: faire du ledger la source de verite produit et du contexte natif un accelerateur opportuniste.

- Risque: collision entre plusieurs profils ecrivant simultanement sur le meme projet.
Mitigation: verrou de projet, journal d'evenements, et mode read-only pour les sessions concurrentes en V1.

## Open Questions

- quelle methode d'isolation de compte Codex est effectivement supportee sans comportement non documente ?
- veut-on gerer un seul compte actif a la fois ou plusieurs runtimes paralleles ?
- jusqu'ou va la reprise automatique du contexte natif par rapport au handoff structure ?
- quels champs minimum d'abonnement ou de limite sont reellement exploitables localement ?

## Test Coverage Map

- Unit: parsing du ledger, ecriture des evenements, resolution du prochain compte, verrouillage projet
- Integration: creation compte, run, handoff, reprise sur un meme projet
- End-to-end: projet A demarre sur compte 1, bascule sur compte 2, historique du projet intact
- UX validation: affichage clair des etats `active`, `limited`, `unknown`, `handoff-required`

## Success Criteria

Le produit est reussi si:
- un utilisateur peut traiter un meme projet sur plusieurs comptes Codex sans perdre le fil
- l'historique projet reste lisible meme si l'historique natif de chaque compte est fragmente
- la bascule de compte devient une operation normale et non une rupture de contexte
