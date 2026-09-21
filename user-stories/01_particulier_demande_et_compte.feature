# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le particulier », étapes 1 à 3

@particulier @actuel
Fonctionnalité: Dépôt de la demande et création du compte acquéreur
  En tant que particulier souhaitant acquérir un bien immobilier
  Je veux déposer une demande de recherche et être mis en relation avec un chasseur
  Afin de démarrer mon projet d'achat accompagné

  @formulaire
  Scénario: Le particulier formule une demande via le formulaire en ligne
    Étant donné que je suis un visiteur du site web de l'entreprise
    Quand je remplis et je soumets le formulaire de demande de recherche
    Alors ma demande est enregistrée dans le système
    Et un processus d'affectation d'un chasseur est déclenché

  @notification @affectation
  Scénario: Le particulier reçoit une notification présentant le chasseur affecté
    Étant donné qu'une demande de recherche a été soumise et qu'un chasseur lui a été affecté
    Quand l'affectation est confirmée
    Alors je reçois une notification m'indiquant le chasseur qui va s'occuper de mon besoin
    Et cette notification m'invite à finaliser la création de mon compte utilisateur sur l'espace acquéreur

  @creation-compte
  Scénario: Le particulier finalise la création de son compte sur l'espace acquéreur
    Étant donné que j'ai reçu la notification d'affectation de mon chasseur
    Quand je finalise la création de mon compte sur l'espace acquéreur du site web
    Alors mon compte est activé
    Et je peux accéder à l'espace acquéreur pour suivre ma recherche

  @premier-rendez-vous @signature-mandat
  Scénario: Le particulier effectue un premier point avec le chasseur et signe le mandat
    Étant donné que mon compte acquéreur est créé et qu'un chasseur m'est affecté
    Quand j'effectue un premier point avec le chasseur pour préciser ma recherche
    Et que je signe le mandat de recherche à l'issue de cet échange
    Alors le mandat de recherche est enregistré avec sa date de signature, son mode (exclusif ou non-exclusif) et sa date de fin de validité
    Et ma recherche est officiellement lancée
