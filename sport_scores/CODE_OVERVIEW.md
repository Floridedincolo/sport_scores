# Sport Scores — Prezentare detaliată a proiectului

Aplicație **Flutter** (Dart) pentru Android care afișează scoruri live, programări și detalii pentru 7 sporturi: fotbal, baschet, hochei, baseball, handbal, Formula 1, tenis. Datele sunt agregate din mai multe API-uri publice, cu sistem de fallback și cache local.

---

## 1. Arhitectura generală

Proiectul respectă pattern-ul **MVVM cu Provider** (state management oficial recomandat pentru Flutter):

```
┌──────────────────────────────────────────────────────────┐
│  UI Layer (Screens + Widgets)                            │
│  • home_screen, sport_tab_view, fixture_detail_screen    │
│  • favorites_screen                                      │
└──────────────┬───────────────────────────────────────────┘
               │ context.watch / context.read
┌──────────────▼───────────────────────────────────────────┐
│  State Layer (ChangeNotifier Providers)                  │
│  • SportProvider, FixturesProvider                       │
│  • FixtureDetailProvider, FavoritesProvider              │
└──────────────┬───────────────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────────┐
│  Service Layer                                           │
│  • SportApiFactory (multiplexor API)                     │
│  • LiveMonitorService, NotificationService               │
│  • FavoritesService, CacheService                        │
└──────────────┬───────────────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────────┐
│  Data Sources                                            │
│  • API-Sports (REST, key)        • The Odds API          │
│  • SportsAPIPro (RapidAPI)       • ESPN public site API  │
│  • NHL.com / MLB statsapi        • SharedPreferences     │
└──────────────────────────────────────────────────────────┘
```

### Stack tehnic
- **Flutter / Dart** — UI cross-platform
- **provider** — state management (ChangeNotifier + MultiProvider)
- **http** — apeluri REST
- **shared_preferences** — persistență cheie/valoare (rate limiter, cache scoruri)
- **hive** + **hive_flutter** — DB locală pentru `Favorite` și `MatchSnapshot` (cu generatoare `.g.dart`)
- **cached_network_image** — cache logo-uri echipe/ligi
- **flutter_local_notifications** — notificări push când un meci favorit își schimbă scorul
- **flutter_background_service** — serviciu Android care monitorizează în fundal

---

## 2. Structura directorului `lib/`

```
lib/
├── main.dart               # Entry point. Inițializează servicii și înregistrează provider-ele.
├── app.dart                # Widget rădăcină + tema globală
│
├── config/
│   ├── constants.dart      # Cheile API (API-Sports, Odds, RapidAPI), URL-uri de bază
│   └── theme.dart          # Paletă de culori (AppColors) și ThemeData dark
│
├── models/                 # Tipurile de date imutabile (POJO-style)
│   ├── sport.dart          # enum SportType { football, basketball, ... }
│   ├── league.dart         # League { id, name, country, logo, currentSeason }
│   ├── team.dart           # Team { id, name, logo }
│   ├── score.dart          # Score { home, away, periods }
│   ├── fixture.dart        # Meci/race: id, sport, league, teams, date, status, score
│   ├── fixture_event.dart  # Eveniment dintr-un meci (gol, schimbare, play-by-play)
│   ├── match_statistics.dart  # Statistici meci: List<{label, home, away}>
│   ├── h2h_entry.dart      # Întâlniri directe (Head-to-Head)
│   ├── standing_row.dart   # Rând clasament: rank, team, played, W/D/L, points
│   ├── favorite.dart       # Meci adăugat la favorite (persistent în Hive)
│   └── match_snapshot.dart # Stare salvată ca să detectăm schimbări de scor
│
├── providers/              # ChangeNotifier — sursa de adevăr pentru UI
│   ├── sport_provider.dart        # Sport selectat în tab-bar
│   ├── fixtures_provider.dart     # Meciuri pe dată, live, filtru pe ligă
│   ├── fixture_detail_provider.dart  # Detalii meci: events, stats, h2h, standings
│   └── favorites_provider.dart    # Listă favorite + sincronizare cu serviciul
│
├── services/               # Logica de business
│   ├── api/
│   │   ├── api_client.dart           # Client REST de bază (cache + rate limit)
│   │   ├── sport_api_factory.dart    # Punct unic de acces la toate API-urile
│   │   ├── football_api.dart         # API-Sports football
│   │   ├── basketball_api.dart       # API-Sports basket + ESPN NBA
│   │   ├── hockey_api.dart           # API-Sports hockey + NHL.com
│   │   ├── baseball_api.dart         # API-Sports baseball + MLB statsapi
│   │   ├── handball_api.dart         # API-Sports handball
│   │   ├── formula1_api.dart         # API-Sports F1
│   │   ├── sportsapipro_client.dart  # RapidAPI fallback (tenis + play-by-play)
│   │   ├── odds_api_client.dart      # The Odds API — fallback pentru live
│   │   ├── espn_standings_client.dart # ESPN — clasamente curente, fără limită de plan
│   │   └── standings_parser.dart     # Parser comun pentru standings non-football
│   ├── cache_service.dart      # Cache in-memory cu TTL pe cheie
│   ├── favorites_service.dart  # CRUD pe Hive box "favorites"
│   ├── match_snapshot_service.dart  # Snapshot-uri pentru detectare schimbări
│   ├── live_monitor_service.dart    # Polling pe meciurile favorite + notificări
│   ├── notification_service.dart    # Wrapper flutter_local_notifications
│   └── background_bootstrap.dart    # Pornește serviciul de fundal pe Android
│
├── screens/                # Pagini full-screen
│   ├── home/
│   │   ├── home_screen.dart        # Scaffold cu BottomNav (Scores | Favorites)
│   │   └── sport_tab_view.dart     # Conținutul tab-ului "Scores"
│   ├── favorites/
│   │   └── favorites_screen.dart   # Lista meciuri marcate favorite
│   └── fixture/
│       ├── fixture_detail_screen.dart  # Pagina meciului
│       └── sections/
│           ├── stats_section.dart      # Statistici (formatare per sport)
│           ├── h2h_section.dart        # Head-to-Head (ultime întâlniri)
│           └── standings_section.dart  # Clasament cu echipele highlight
│
├── widgets/                # Widget-uri reutilizabile
│   ├── common/             # LoadingIndicator, AppErrorWidget, EmptyState
│   ├── fixture/            # FixtureCard, ScoreDisplay, LiveBadge
│   └── home/               # SportTabBar (selector orizontal de sport)
│
└── utils/
    ├── api_rate_limiter.dart  # Limitator request-uri (free plan API-Sports)
    ├── team_matching.dart     # Algoritm fuzzy match nume echipe între API-uri
    └── date_utils.dart        # Formatări date relative (Today, Yesterday)
```

---

## 3. Layer-ul de date — agregare multi-API

Aplicația **nu se bazează pe un singur API**. Pentru fiecare sport am orchestrat mai multe surse cu fallback automat, ca să maximizez acoperirea în condițiile limitelor planurilor gratuite.

### `SportApiFactory` (`services/api/sport_api_factory.dart`)
Singurul punct de acces. Provider-ele cer `apiFactory.football`, `apiFactory.basketball` etc. și primesc clientul potrivit. Inițializează lazy (instanțele se creează la prima utilizare) prin `Map<SportType, dynamic> _cache`.

### `ApiClient` (`services/api/api_client.dart`)
Wrapper peste `http.Client` cu:
- **rate limiter** (`ApiRateLimiter`) — respectă plafonul zilnic de request-uri al API-Sports free tier (100/zi). Salvează contorul în `SharedPreferences` cu reset la miezul nopții UTC.
- **cache TTL per cheie** — `cacheTtl: Duration(minutes: 5)` pe parametri request → răspuns reutilizat fără request nou.
- **rezolvare host per sport** — fiecare sport are subdomain propriu (`v3.football.api-sports.io`, `v1.basketball.api-sports.io` etc.).

### Sursele de date și de ce-s necesare toate
| Sursă | Folosit pentru | De ce |
|---|---|---|
| **API-Sports** (api-sports.io) | Sursa primară: meciuri, scoruri, statistici, clasamente | Plan gratuit cu 100 req/zi, acoperire bună 6 sporturi |
| **ESPN public site API** | Clasamente curente fotbal, NBA, NHL, MLB | Free, fără cheie, **fără restricție de sezon** (rezolvă limita „free plan = doar 2022-2024" de la API-Sports) |
| **The Odds API** | Live scores fallback NBA/NHL/MLB | Acoperă goluri pe zile când API-Sports nu are date |
| **SportsAPIPro** (RapidAPI) | Play-by-play și meciuri tenis | Singurul provider pentru tenis în acest proiect |
| **NHL.com / MLB statsapi** | Play-by-play oficial | Detalii granulare pe care API-urile generaliste nu le au |

### Pattern de fallback (exemplu fotbal — clasamente)
Vezi `fixture_detail_provider.dart`, secțiunea `case SportType.football`:

```
1. Încearcă ESPN (sezon curent, gratis)         → SUCCESS → return
2. Dacă eșuează, încearcă API-Sports cu sezonul curent
3. Dacă free plan blochează, fallback la 2024, 2023, 2022
4. Marchează în UI sezonul efectiv afișat
```

---

## 4. State management cu Provider

Fiecare provider extinde `ChangeNotifier` și expune doar getters; mutațiile sunt metode `Future<void>` ce apelează `notifyListeners()` la final. UI-ul ascultă cu `context.watch<X>()` și se reconstruiește automat.

### `SportProvider`
Reține tab-ul de sport selectat. Listă `availableSports` ordonată după preferință.

### `FixturesProvider` — inima ecranului principal
Stări:
- `_liveFixtures` — meciuri live în acest moment
- `_dateFixtures` — toate meciurile pentru data selectată
- `_selectedDate`, `_selectedLeague` — filtre

Getters derivate:
- `filteredFixtures` — aplică filtrul de ligă peste `_dateFixtures`
- `filteredByLeague` — grupează rezultatul după ligă, cu **ligile populare prima** (Liga I, Premier League, La Liga... pentru fotbal)
- `availableLeagues` — listă unică ligi din meciurile încărcate, sortate cu populare prima

Constanta `_popularLeagueIds` — set de ID-uri pe care le considerăm "populare" per sport. Pentru fotbal: `{283, 39, 140, 135, 78, 61, 2, 3, 848}` — Liga I e prima.

### `FixtureDetailProvider`
Pentru pagina de meci. Pe `fetchDetail(sport, fixtureId)`:
1. Încarcă meciul în sine (`getFixtureById` per sport)
2. Lansează **în paralel** (`Future.wait`) restul:
   - Evenimente / play-by-play (cu fallback API-uri secundare)
   - Statistici (`stats`)
   - Head-to-Head (`h2h`)
   - Clasament (`standings`) — încearcă ESPN întâi, apoi API-Sports
3. Fiecare apel e wrappuit într-un `safe(...)` — dacă unul eșuează, restul continuă

### `FavoritesProvider`
Persistă în Hive prin `FavoritesService`. La toggle, scrie în box și notifică UI-ul. `LiveMonitorService` ascultă această listă și polluiază API-ul la fiecare X minute pentru meciurile favorite live.

---

## 5. UI — pagini și fluxuri

### HomeScreen
Scaffold cu `BottomNavigationBar` cu **2 tab-uri**: **Scores** și **Favorites**. Folosește `IndexedStack` ca să păstreze starea fiecărui tab.

### SportTabView (Scores)
1. **Header** "Sport Scores" + badge LIVE
2. **SportTabBar** orizontal — selector de sport
3. **LIVE NOW** — carusel orizontal cu meciuri în desfășurare
4. **Date strip** — yesterday / today / tomorrow
5. **League filter chips** — pe baza ligilor distincte din meciurile zilei. "All" sau o ligă specifică.
6. **Meciuri grupate pe ligi** — fiecare ligă are header (țară + nume) și sub el FixtureCard-uri

Liga I apare automat în chips când există meciuri de Superliga în ziua respectivă, și e prima datorită ordinii din `_popularLeagueIds`.

Pentru F1, layout-ul e diferit: secțiuni "UPCOMING RACES" și "FINISHED RACES" în loc de date strip (cursele nu sunt zilnice).

### FixtureDetailScreen
Layout structurat:
1. **AppBar** cu buton ← și icon stea (favorit toggle)
2. **Scoreboard** — logo-uri echipe, scor, status (LIVE / FT / scheduled)
3. **Statistics** (collapsible) — formatare specifică per sport:
   - Fotbal: bare orizontale (posesie, șuturi, cornere, faulturi)
   - Basket: tabel coloane (FG%, 3P%, rebounds, assists, turnovers)
   - Baseball: hits / runs / errors per inning
   - Hockey/handbal: bare cu shots, saves, penalties
4. **Head-to-Head** (collapsible) — listă ultimele întâlniri directe între aceleași echipe (fotbal + basket)
5. **Standings** (collapsible) — clasament ligă, cu rândurile celor 2 echipe **highlight**. Suportă **grupe** (ex. Group A / Group B în UCL): rândurile sunt împărțite vizual cu titlu de grup
6. **Events / Play-by-Play** — text scrolabil al evenimentelor:
   - Fotbal: goluri, cartonașe, schimbări (cu minut)
   - Basket: scoring plays grupate pe Q1-Q4 + OT
   - Hockey: goluri / penalități pe perioade
   - Baseball: hits / runs grupate pe innings (▲ Top / ▼ Bot)
   - Handbal: goluri pe reprize
   - Tenis: comentariu pe seturi
   - F1: pozițiile finale + race control + pit stops

### FavoritesScreen
Aceleași `FixtureCard`-uri, dar doar pentru meciurile marcate. Lista e reactivă (Hive box → provider → UI).

---

## 6. Servicii de fundal și notificări

### LiveMonitorService
Rulează un `Timer.periodic` la **60 secunde**:
1. Citește lista favorite
2. Pentru fiecare meci favorit cu status live, cere starea curentă
3. Compară cu ultimul snapshot din `MatchSnapshotService`
4. Dacă scorul s-a schimbat → trimite notificare locală prin `NotificationService`
5. Salvează snapshot-ul nou

Două instanțe rulează: una **foreground** (pornită din `app.dart`) și una **background** (Android foreground service prin `flutter_background_service`). Pe iOS, sistemul nu garantează rulare în background — limitare de platformă.

### NotificationService
Wrapper peste `flutter_local_notifications`:
- canal Android dedicat ("score_updates")
- payload conține `fixtureId` ca să deschidă direct pagina meciului la tap
- permisiuni cerute la pornire

---

## 7. Persistență

### Hive (`favorites` și `match_snapshots`)
- `Favorite` — meci salvat de user; cheie = `fixtureId`
- `MatchSnapshot` — ultimul scor cunoscut pentru detectarea diff-ului
- Generatorul `hive_generator` produce automat fișierele `.g.dart` (TypeAdapter-e)

### SharedPreferences
- Contor request-uri API-Sports per zi
- Configurări mici (ex. data ultimei sincronizări)

### CacheService (in-memory)
- Map cu TTL: `{key: (value, expiryTs)}`
- Folosit de `ApiClient` ca să evite request-uri duplicate într-o sesiune

---

## 8. Detalii notabile de implementare

### Fuzzy matching de nume echipe (`utils/team_matching.dart`)
ESPN și API-Sports folosesc nume diferite pentru aceeași echipă ("Manchester City" vs "Man City", "Bayern Munich" vs "FC Bayern München"). Algoritm:
1. Normalizare (lowercase, strip diacritice)
2. Match exact → match prefix → match contains
3. Bigrame Jaccard ca scor final

Folosit la lookup-ul ID-urilor între API-uri (ex. ESPN game id pentru un meci API-Sports).

### Rate limiter (`utils/api_rate_limiter.dart`)
Plan gratuit API-Sports = 100 req/zi. Implementare:
- Counter persistent în SharedPreferences
- Reset la miezul nopții UTC
- Înainte de fiecare request: verifică buget, dacă e atins → throw `RateLimitException`
- Cache-ul agresiv (5 min default) ține numărul jos

### Suport pentru grupe în clasamente
`StandingRow` are câmpul `group` (nullable). În `StandingsSection`, rândurile se împart vizual pe grupe cu titlu separator. Util pentru:
- UCL/UEL/UECL faza de grupe
- ligă cu Conference (East/West NBA)
- liga ucraineană handbal

### Highlight echipe în clasament
Match după **id ȘI după nume** (case-insensitive, contains). Necesar pentru că standings poate veni dintr-un sezon diferit unde ID-urile interne ale API-ului diferă, dar numele rămâne stabil.

---

## 9. Tratarea erorilor

Trei niveluri:
1. **Rețea / parsing** — try/catch în fiecare metodă API; throw `ApiException` cu mesaj descriptiv
2. **Provider** — pune `_state = LoadingState.error` și păstrează mesajul; UI afișează `AppErrorWidget` cu buton retry
3. **Funcționalitate accesorie** — pentru stats / h2h / standings, folosesc `safe(label, fn)` care doar logghează și ignoră (UI sare peste secțiunea respectivă elegant — fără a strica meciul)

---

## 10. Concluzii și demonstrabil

Ce-am demonstrat construind acest proiect:
- **Pattern arhitectural Provider** pentru state management într-o app Flutter mid-size
- **Agregare de surse multiple de date** cu fallback și cache
- **Programare asincronă** intensă cu `Future.wait` paralel
- **Persistență locală** cu două sisteme (Hive cu code-gen + SharedPreferences)
- **Servicii de fundal Android** și **notificări locale**
- **UI specializat per domeniu** — același ecran (FixtureDetailScreen) afișează 7 sporturi cu randări complet diferite
- **Tratarea limitelor reale** — rate limit, restricții de sezon pe plan gratuit, nume diferite în surse — toate gestionate transparent

Demo-ul rulează pe emulator Android, build prin `flutter run`.
