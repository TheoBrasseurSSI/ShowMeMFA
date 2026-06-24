Auteur : Théo Brasseur | https://github.com/TheoBrasseurSSI | https://linkedin.com/in/tbrasseur
---
Outil PowerShell d'audit des méthodes d'authentification multifacteur (MFA) Microsoft 365. Il permet à un administrateur de visualiser, pour un utilisateur donné, l'ensemble des méthodes MFA enregistrées (Microsoft Authenticator, téléphone, clé FIDO2, Windows Hello, etc.) — utile pour détecter une méthode ajoutée frauduleusement par un attaquant comme moyen de persistance après compromission.
---
⚠ Cet outil est en lecture uniquement, il ne modifie ni ne supprime aucune méthode MFA.
---
Prérequis
* Compte Microsoft 365 avec au moins l'un des rôles suivants :
* Global Administrator
* ou Authentication Administrator
* ⚠ Ne pas exécuter dans PowerShell ISE
---
Périmètre de l'audit
* L'outil cible un utilisateur précis, saisi manuellement
* Les méthodes détectées et affichées :
* Microsoft Authenticator (avec le nom de l'appareil si disponible)
* Téléphone (SMS/Appel) avec le numéro associé
* Clé de sécurité FIDO2 (avec le modèle si disponible)
* Windows Hello for Business
* Mot de passe
* Application OTP logicielle
* Pass d'accès temporaire (TAP)
* Email
* L'outil propose une boucle pour vérifier plusieurs utilisateurs à la suite
---
Authentification
* Le script utilise le Device Code Flow (flux OAuth2 standard Microsoft).
* À chaque lancement, un code est affiché dans la console. Il faut :
* Ouvrir le lien affiché (https://microsoft.com/devicelogin)
* Saisir le code affiché
* Se connecter avec le compte admin souhaité
* Cette méthode permet de choisir librement le compte à chaque exécution, quel que soit le tenant ciblé.
* Aucune session n'est mise en cache — la connexion est isolée à la session PowerShell en cours.
* ⚠ Le compte utilisé doit avoir les droits suffisants pour lire les méthodes d'authentification sur le tenant ciblé.
---
Saisie utilisateur
Lors de l'exécution, le script demande :
* L'adresse email de l'utilisateur à auditer (ou Q pour quitter)
* Une fois les résultats affichés, propose de vérifier un autre utilisateur ou de quitter
---
Lancement
* Créez un raccourci de Launcher.bat → clic-droit → Créer un raccourci.
* Le fichier .bat :
* applique une ExecutionPolicy Bypass (temporaire, pour la session uniquement)
* exécute ensuite le script ShowMeMFA.ps1
* ⚠ Le fichier Launcher.bat et le fichier ShowMeMFA.ps1 doivent rester dans le même dossier.
* Un fichier .ico est fourni pour l'icône de votre raccourci.
---
Exécution manuelle
Le script peut aussi être lancé directement depuis PowerShell :
powershell.exe -ep Bypass -File .\ShowMeMFA.ps1
Le bypass est temporaire et n'applique aucune modification permanente sur le poste.
---
Logs
* Un fichier de log est automatiquement généré à chaque exécution.
* Le dossier logs\ est créé automatiquement au premier lancement, aucune action manuelle nécessaire.
* Les logs sont stockés dans le dossier logs\ à la racine du projet.
* Chaque fichier est nommé avec le timestamp de la session : ShowMeMFA_2026-06-16_08-40.log
* Le log contient : compte admin utilisé, utilisateur audité, détail de chaque méthode MFA trouvée.
* ⚠ Le dossier logs\ est exclu du dépôt Git (.gitignore) — vos logs restent locaux.