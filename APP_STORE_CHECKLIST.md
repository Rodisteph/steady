# Checklist de soumission App Store — Steady

## ✅ Déjà fait (dans ce commit)

- [x] **Icône d'app** 1024×1024 générée (`Steady/Assets.xcassets/AppIcon.appiconset/AppIcon.png`)
- [x] **AccentColor** rempli (vert sauge, clair + sombre)
- [x] **Manifeste de confidentialité** valide (`Steady/PrivacyInfo.xcprivacy`) — corrigé (nom, emplacement, structure)
- [x] **Conformité chiffrement** : `ITSAppUsesNonExemptEncryption = NO` (évite le questionnaire export à chaque build)
- [x] **Liens légaux** centralisés dans `Steady/Utils/AppLinks.swift`
- [x] **Politique de confidentialité** (`PRIVACY.md`) et CGU (`TERMS.md`) rédigées (domaine + email renseignés)
- [x] **URL légales** configurées dans `AppLinks.swift` → `https://rodisteph.github.io/steady/{privacy,terms}`
- [x] **Config StoreKit locale** (`Steady/Configuration.storekit`) + scheme partagé branché → l'achat « Premium » fonctionne en test
- [x] **Captures d'écran 6,9"** (1320×2868) générées dans `AppStore/screenshots/` (Accueil, Résumé, Premium)
- [x] **Refonte visuelle premium** (design system, anneau de progression, streaks, animations)

## ⚠️ À faire avant de soumettre (action de ta part requise)

### 1. Publier les pages légales sur GitHub Pages (BLOQUANT)
Le code pointe déjà vers `https://rodisteph.github.io/steady/...`. Il reste à publier :
- [ ] Crée un repo public `steady` sur le compte GitHub **Rodisteph**
- [ ] Active **GitHub Pages** (Settings → Pages → branche `main`)
- [ ] Convertis `PRIVACY.md` → `privacy.html` (ou `privacy/index.html`) et `TERMS.md` → `terms.html`
- [ ] Vérifie que `https://rodisteph.github.io/steady/privacy` s'ouvre bien
- [ ] Renseigne cette URL dans **App Store Connect** (champ « Privacy Policy URL »)

### 2. Créer l'achat dans App Store Connect (BLOQUANT pour le Premium)
La config locale fonctionne en test ; côté production il faut le créer réellement :
- [ ] App Store Connect → ton app → **Monétisation → Achats intégrés → +**
- [ ] Type : **Non consommable**
- [ ] **Product ID exact** : `com.yourcompany.steady.premium.unlock`
      (identique à `Steady/Store/StoreManager.swift:7` et à `Configuration.storekit`)
- [ ] Renseigne prix (ex : 3,99 €), nom affiché « Steady Premium », description, capture de la fiche
- [ ] Teste l'achat + la restauration avec un compte **Sandbox**

### 3. Métadonnées App Store Connect
- [ ] Nom, sous-titre, description, mots-clés, catégorie (Productivité / Style de vie)
- [x] **Captures 6,9"** prêtes dans `AppStore/screenshots/` (téléverse-les ; ajoute la taille 6,5" si demandée)
- [ ] URL de support
- [ ] Section « Confidentialité de l'app » (App Privacy) : déclare **« Aucune donnée collectée »**
      (cohérent avec le manifeste et `PRIVACY.md`)
- [ ] Classification d'âge (probablement 4+)

### 4. Build & signature
- [ ] `DEVELOPMENT_TEAM` déjà défini (`V3BB9YS6N2`) — vérifie le provisioning
- [ ] Incrémente `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` à chaque upload
- [ ] Archive (`Product > Archive`) puis distribue via Xcode Organizer ou Transporter

## 💡 Recommandé (qualité)

- [ ] Vérifier le rendu en mode sombre et avec Dynamic Type (grandes polices)
- [ ] Tester sur un petit appareil (iPhone SE) pour les débordements

## 🧪 Note dev — données de démo pour captures

Un helper `#if DEBUG` (jamais compilé en production) permet de régénérer les
captures avec un jeu de données propre, via des arguments de lancement :

```
xcrun simctl launch <SIM_ID> Rodrigo.Steady -seedDemo -tab 0      # Accueil
xcrun simctl launch <SIM_ID> Rodrigo.Steady -tab 1               # Résumé
xcrun simctl launch <SIM_ID> Rodrigo.Steady -tab 0 -showPremium  # Premium
```

`-seedDemo` insère 4 habitudes d'exemple (voir `HabitStore.seedDemoData()`).
