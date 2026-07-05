# Politique de confidentialité — Steady

_Dernière mise à jour : 5 juillet 2026_

Steady (« l'application ») est conçue dans le respect de votre vie privée. Cette
politique explique quelles données sont traitées et comment.

## En résumé

- **Vos habitudes restent privées et locales.** Tout ce qui concerne le suivi de
  vos habitudes ne quitte jamais votre téléphone.
- **La partie « Communauté » est totalement optionnelle.** Elle ne s'active que
  si vous choisissez de vous connecter avec Apple. Tant que vous ne vous
  connectez pas, **aucune donnée n'est transmise**.

## Données stockées uniquement sur votre appareil

- **Vos habitudes et validations** sont stockées **uniquement sur votre
  appareil** (base de données locale SwiftData). Elles ne quittent jamais votre
  téléphone.
- **Vos préférences** (mode bienveillance, thème, langue, heures de rappel) sont
  enregistrées localement via UserDefaults.
- **Notifications** : les rappels sont planifiés localement par iOS. Aucun
  serveur n'est impliqué.

## Données traitées si vous utilisez la Communauté (optionnel)

Si — et seulement si — vous vous connectez à la section « Communauté » via
**Sign in with Apple**, les données suivantes sont enregistrées sur les serveurs
de **Google Firebase** (notre prestataire technique) afin de faire fonctionner
les amis, les classements et les groupes :

- **Un identifiant de compte** fourni par Apple/Firebase (un code anonyme ; nous
  ne recevons **pas** votre adresse e-mail).
- **Votre pseudo** et l'icône d'avatar que vous choisissez.
- **Des statistiques de progression** que vous acceptez de partager : niveau,
  score, longueur de série.
- **Votre liste d'amis** et les demandes d'amis.
- **Les messages** que vous envoyez dans les groupes auxquels vous appartenez.

Ces données ne sont visibles que par vous et les personnes avec qui vous
interagissez (vos amis, les membres de vos groupes). Nous ne les vendons pas et
ne les utilisons pas à des fins publicitaires.

## Prestataire (sous-traitant)

L'infrastructure Communauté repose sur **Google Firebase** (authentification et
base de données). À ce titre, Google traite ces données pour notre compte. Voir
la [politique de confidentialité de Google](https://policies.google.com/privacy).

## Achats intégrés

L'achat « Premium » est traité par **Apple via StoreKit**. Nous ne recevons ni
ne stockons vos informations de paiement. Voir la
[politique de confidentialité d'Apple](https://www.apple.com/legal/privacy/).

## Publicité (Google AdMob)

Steady propose, **uniquement sur votre demande explicite**, de regarder une
courte vidéo publicitaire pour débloquer les fonctions Premium pendant 24
heures. Aucune publicité ne s'affiche sans que vous appuyiez sur ce bouton, et
les personnes ayant acheté Premium ne voient jamais de publicité.

Ces publicités sont servies par **Google AdMob** (Google Ireland Ltd. pour
l'Union européenne), qui agit comme partenaire publicitaire. Dans ce cadre,
Google peut traiter :

- **Des identifiants d'appareil** (par ex. identifiant publicitaire) et des
  informations techniques (modèle d'appareil, version d'iOS, langue).
- **Des données d'utilisation liées aux publicités** (diffusion, interactions,
  diagnostics) à des fins d'affichage, de mesure et de prévention de la fraude.

**Consentement (RGPD)** : dans l'Espace économique européen (dont la France,
l'Espagne et le Portugal), un formulaire de consentement s'affiche avant toute
publicité. Si vous refusez, des publicités **non personnalisées** sont servies.
Vous pouvez modifier votre choix à tout moment. Voir
[comment Google utilise les données](https://policies.google.com/technologies/partner-sites)
et la [politique de confidentialité de Google](https://policies.google.com/privacy).

## Suivi (tracking)

En dehors du cadre publicitaire décrit ci-dessus, Steady ne suit pas votre
activité à travers d'autres apps ou sites, et vos données d'habitudes ne sont
**jamais** partagées avec des annonceurs.

## Vos droits et la suppression de votre compte

- Vos données locales sont effacées en supprimant une habitude ou en
  désinstallant l'application.
- Pour la Communauté : vous pouvez **vous déconnecter** à tout moment, et
  **supprimer définitivement votre compte et toutes vos données serveur**
  directement depuis l'application (section Communauté → Supprimer mon compte).
- Vous pouvez aussi nous écrire pour exercer vos droits d'accès, de rectification
  ou de suppression.

## Enfants

Steady ne s'adresse pas aux enfants de moins de 13 ans et ne collecte pas
sciemment leurs données.

## Contact

Pour toute question : **rdrgbouabida@gmail.com**

---

> ℹ️ **À faire avant publication** : publiez cette page sur GitHub Pages à
> `https://rodisteph.github.io/steady/privacy.html` (URL déjà configurée dans
> `Steady/Utils/AppLinks.swift`), puis renseignez la même URL dans App Store
> Connect. **Mettez aussi à jour la section « Confidentialité de l'app »**
> (App Privacy) dans App Store Connect pour déclarer les données collectées
> ci-dessus (Identifiant, Contenu utilisateur, Contacts/Amis), **plus les
> données AdMob** : Identifiants (ID d'appareil), Données d'utilisation
> (interactions publicitaires), Diagnostic — finalité « Publicité par des
> tiers ». Cochez aussi « Cette app contient des publicités » dans la fiche.
