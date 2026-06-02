# Nearby Shop Finder API

Node.js + Express + PostgreSQL (PostGIS) Backend.

## Voraussetzungen

- **Docker Desktop** (für PostgreSQL mit PostGIS)
- **Node.js 20+**
- **Firebase Service Account** (JSON-Schlüssel)

## Setup

### 1. Firebase Service Account

1. Gehe zur [Firebase Console](https://console.firebase.google.com/project/shopfinder-5f670/settings/serviceaccounts)
2. Klicke auf **"Neuen privaten Schlüssel generieren"**
3. Speichere die Datei als `server/firebase-service-account.json`

### 2. PostgreSQL starten (Docker)

```bash
docker compose up postgres -d
```

### 3. Umgebungsvariablen

`.env` ist bereits vorhanden. Passe bei Bedarf die Werte an.

### 4. Server starten

```bash
cd server
npm run dev
```

Der Server läuft auf `http://localhost:3000`.

### Migrationen

Migrationen laufen automatisch beim Server-Start (`npm run dev`).
Manuell: `npm run migrate`

## API-Endpunkte

### Auth
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| POST | `/api/auth/verify` | - | Firebase-Token verifizieren → JWT erhalten |
| GET | `/api/auth/me` | JWT | Aktuellen Benutzer abrufen |

### Companies
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| GET | `/api/companies` | - | Unternehmen auflisten (mit Geo-Suche) |
| GET | `/api/companies/:id` | - | Unternehmen-Details |
| POST | `/api/companies` | JWT | Unternehmen erstellen |
| PUT | `/api/companies/:id` | JWT | Unternehmen bearbeiten |
| DELETE | `/api/companies/:id` | JWT | Unternehmen löschen |
| POST | `/api/companies/:id/view` | - | Aufruf zählen |

### Reviews
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| GET | `/api/reviews/companies/:id/reviews` | - | Firmen-Bewertungen |
| POST | `/api/reviews/companies/:id/reviews` | JWT | Bewertung erstellen |
| GET | `/api/reviews/services/:id/reviews` | - | Service-Bewertungen |
| POST | `/api/reviews/services/:id/reviews` | JWT | Service-Bewertung |

### Services
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| GET | `/api/services` | - | Services auflisten |
| GET | `/api/services/:id` | - | Service-Details |
| POST | `/api/services` | JWT | Service erstellen |
| PUT | `/api/services/:id` | JWT | Service bearbeiten |
| DELETE | `/api/services/:id` | JWT | Service löschen |

### Proxy (API-Key-Schutz)
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| POST | `/api/proxy/gemini` | JWT | Gemini API-Aufruf (serverseitiger Key) |
| POST | `/api/proxy/places` | JWT | Google Places Suche |
| POST | `/api/proxy/places/details` | JWT | Google Places Details |
| POST | `/api/proxy/nominatim` | - | OpenStreetMap-Suche |

### Suche
| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| GET | `/api/search` | - | Zusammengeführte Shop-Suche |

## Deployment (Railway / Render)

1. Repository mit dem `server/`-Ordner verbinden
2. Umgebungsvariablen setzen (siehe `.env.example`)
3. `firebase-service-account.json` als Secret/Environment einrichten
4. Build-Befehl: `npm install`
5. Start-Befehl: `npm start`
