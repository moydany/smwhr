# smwhr — API Contracts

Especificación de los contratos que el frontend espera del backend. Se construye PRIMERO el frontend con mocks que cumplen estos contratos, DESPUÉS el backend implementa para cumplirlos.

**Versión:** v1.0
**Base URL dev:** `http://localhost:3000`
**Base URL prod:** `https://api.smwhr.quest`
**Authentication:** Bearer JWT en header `Authorization: Bearer <token>`

---

## 🔐 Authentication

### POST /auth/apple

Sign in con Apple. Mobile manda el identityToken obtenido del flow nativo.

**Request:**
```json
{
  "identityToken": "eyJhbGciOiJSUzI1NiIs...",
  "authorizationCode": "c1234abcd..."
}
```

**Response 200:**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "expiresIn": 604800,
  "user": {
    "id": "uuid",
    "email": "user@privaterelay.appleid.com",
    "handle": null,
    "displayName": null,
    "onboardingCompletedAt": null
  }
}
```

Si onboardingCompletedAt es null, mobile debe ir a flow de onboarding. Si tiene valor, ir directo a Home.

### POST /auth/google

```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIs..."
}
```

Response idéntico al de Apple.

### POST /auth/email/request

```json
{
  "email": "user@example.com"
}
```

**Response 200:**
```json
{
  "success": true,
  "message": "Magic link sent"
}
```

Backend manda email con link tipo `https://smwhr.quest/auth/verify?token=xyz`.

### POST /auth/email/verify

```json
{
  "token": "xyz"
}
```

Response: AuthSession completa.

### POST /auth/refresh

```json
{
  "refreshToken": "eyJ..."
}
```

**Response:**
```json
{
  "accessToken": "eyJ...",
  "expiresIn": 604800
}
```

### POST /auth/logout

Sin body. Header con Bearer token.

**Response 204** (no content).

---

## 👤 Users

### GET /me

Header con Bearer.

**Response 200:**
```json
{
  "id": "uuid",
  "handle": "moi",
  "displayName": "Moi",
  "email": "moi@orbit-m.dev",
  "avatarUrl": null,
  "bio": "Founder. Maker.",
  "city": "Tulancingo",
  "countryCode": "MX",
  "interests": ["music", "sports", "outdoor"],
  "language": "es",
  "timezone": "America/Mexico_City",
  "stats": {
    "questsCount": 23,
    "venuesCount": 8,
    "artistsCount": 14
  },
  "onboardingCompletedAt": "2026-04-22T15:30:00Z",
  "createdAt": "2026-04-22T15:00:00Z"
}
```

### PATCH /me

Update parcial del perfil. Solo campos enviados se actualizan.

**Request:**
```json
{
  "displayName": "Moisés",
  "bio": "Updated bio",
  "city": "Ciudad de México"
}
```

**Response:** User completo actualizado.

### POST /me/onboarding

Completar onboarding. Llamar después de pantalla 04 Permissions.

**Request:**
```json
{
  "handle": "moi",
  "displayName": "Moi",
  "city": "Tulancingo",
  "countryCode": "MX",
  "interests": ["music", "sports", "outdoor"],
  "notificationsEnabled": true,
  "pushToken": "fcm-token-xxx",
  "pushPlatform": "ios"
}
```

**Response 200:**
```json
{
  "user": { /* User object */ },
  "onboardingCompletedAt": "2026-04-22T15:30:00Z"
}
```

**Errors:**
- `409 Conflict`: handle ya tomado
- `400 Bad Request`: handle inválido (caracteres no permitidos)

### GET /users/check-handle/:handle

**Response 200:**
```json
{
  "available": true
}
```

O:
```json
{
  "available": false,
  "reason": "taken" | "reserved" | "invalid"
}
```

### GET /users/:handle

Perfil público (sin email ni info privada).

**Response 200:**
```json
{
  "handle": "moi",
  "displayName": "Moi",
  "avatarUrl": null,
  "bio": "Founder. Maker.",
  "city": "Tulancingo",
  "stats": {
    "questsCount": 23,
    "venuesCount": 8,
    "artistsCount": 14
  },
  "joinedAt": "2026-04-22T15:00:00Z"
}
```

### GET /users/:handle/badges

Colección pública de badges.

**Response 200:**
```json
{
  "badges": [
    {
      "id": "uuid",
      "serialNumber": 1247,
      "totalForEvent": 47832,
      "event": {
        "id": "uuid",
        "title": "World Tour 2026",
        "artist": "BTS",
        "venueName": "Estadio GNP Seguros",
        "city": "Ciudad de México",
        "category": "music",
        "startsAt": "2026-05-07T20:00:00-06:00"
      },
      "composedImageUrl": "https://...",
      "isVerified": true,
      "awardedAt": "2026-05-07T23:30:00Z"
    }
  ],
  "total": 23,
  "page": 1,
  "pageSize": 20
}
```

---

## 📅 Events

### GET /events

**Query params:**
- `city` (optional): "Ciudad de México", "Guadalajara", etc.
- `category` (optional): "music", "sports", "festivals", "outdoor", "culture"
- `featured` (optional): true/false
- `from` (optional): ISO date, default = now
- `to` (optional): ISO date, default = now + 90 days
- `page` (default 1)
- `pageSize` (default 20, max 100)

**Response 200:**
```json
{
  "events": [
    {
      "id": "uuid",
      "slug": "bts-world-tour-cdmx-2026-05-07",
      "title": "World Tour 2026",
      "artist": "BTS",
      "venueName": "Estadio GNP Seguros",
      "city": "Ciudad de México",
      "countryCode": "MX",
      "category": "music",
      "subcategory": "concert",
      "startsAt": "2026-05-07T20:00:00-06:00",
      "endsAt": "2026-05-07T23:30:00-06:00",
      "heroImageUrl": "https://...",
      "heroColor": "#FF2D95",
      "intentCount": 347,
      "intentsFromNetwork": 12,
      "verifiedCount": 0,
      "totalCapacity": 65000,
      "isFeatured": true,
      "userHasIntent": false
    }
  ],
  "total": 16,
  "page": 1,
  "pageSize": 20
}
```

### GET /events/:slug

Event detail completo.

**Response 200:**
```json
{
  "id": "uuid",
  "slug": "bts-world-tour-cdmx-2026-05-07",
  "title": "World Tour 2026",
  "artist": "BTS",
  "venueName": "Estadio GNP Seguros",
  "venueAddress": "Av. Río Churubusco 17, Ciudad de México",
  "city": "Ciudad de México",
  "category": "music",
  "subcategory": "concert",
  "startsAt": "2026-05-07T20:00:00-06:00",
  "endsAt": "2026-05-07T23:30:00-06:00",
  "dwellMinimumMin": 60,
  "heroImageUrl": "https://...",
  "heroColor": "#FF2D95",
  "externalUrl": "https://www.ticketmaster.com.mx/...",
  "intentCount": 347,
  "intentsFromNetwork": 12,
  "verifiedCount": 0,
  "totalCapacity": 65000,
  "userHasIntent": false,
  "questDescription": "Show up. Stay for at least 60 minutes. Capture one moment. Earn a collectible proving you were there — verified by GPS, device trust, and dwell time.",
  "badgePreview": {
    "templateId": "uuid",
    "category": "music",
    "ambientColor": "#FF2D95",
    "previewImageUrl": "https://..."
  }
}
```

### POST /events/:id/intent

Marca "I'll be there".

**Response 200:**
```json
{
  "success": true,
  "intentCount": 348
}
```

### DELETE /events/:id/intent

Remueve intent.

**Response 204** (no content).

### GET /events/:id/intents

Lista de usuarios con intent (público, datos limitados).

**Query params:**
- `network` (optional): true para solo amigos del current user
- `page`, `pageSize`

**Response 200:**
```json
{
  "users": [
    {
      "handle": "sofia",
      "displayName": "Sofía",
      "avatarUrl": null
    }
  ],
  "total": 347
}
```

---

## 🎯 Quests

### GET /quests/:eventId/status

Estado actual de la quest del usuario para ese evento.

**Response 200:**
```json
{
  "isActive": true,
  "startedAt": "2026-05-07T19:14:00Z",
  "dwellMinutes": 47,
  "dwellMinimumMin": 60,
  "checks": {
    "gpsVerified": true,
    "deviceTrusted": true,
    "integrityActive": true,
    "photoCapture": false
  },
  "currentVenue": "Estadio GNP Seguros",
  "verificationScore": 65,
  "willEarnBadge": true
}
```

### POST /quests/:eventId/sync

Batch upload del dual-track. Mobile manda Locus events + geolocator pings.

**Request:**
```json
{
  "locusEvents": [
    {
      "eventType": "geofence_enter",
      "latitude": 19.4010,
      "longitude": -99.2055,
      "accuracy": 8.5,
      "altitude": 2240,
      "speed": 0.5,
      "heading": 180,
      "activity": "walking",
      "confidence": 0.92,
      "timestamp": "2026-05-07T19:14:00Z",
      "isInsidePolygon": true
    }
  ],
  "geolocatorPings": [
    {
      "latitude": 19.4010,
      "longitude": -99.2055,
      "accuracy": 10.3,
      "altitude": 2240,
      "timestamp": "2026-05-07T19:15:00Z",
      "isInsidePolygon": true,
      "batteryLevel": 87
    }
  ],
  "clientTimestamp": "2026-05-07T19:30:00Z",
  "deviceInfo": {
    "id": "device-uuid",
    "model": "iPhone 15 Pro",
    "os": "iOS 18.0",
    "appVersion": "0.1.0"
  }
}
```

**Response 200:**
```json
{
  "received": {
    "locusEvents": 12,
    "geolocatorPings": 6
  },
  "questStatus": { /* QuestStatus actualizado */ }
}
```

### POST /quests/:eventId/integrity

Reportar device integrity check (Apple App Attest o Google Play Integrity).

**Request:**
```json
{
  "platform": "ios",
  "token": "attestation-token-xxx",
  "verifiedAt": "2026-05-07T19:14:00Z"
}
```

**Response 200:**
```json
{
  "verdict": "trusted",
  "verifiedAt": "2026-05-07T19:14:30Z"
}
```

### POST /quests/:eventId/photo

Multipart upload de la foto.

**Request:** multipart/form-data
- `photo`: image file
- `exifTimestamp`: ISO date
- `exifLatitude`: float
- `exifLongitude`: float

**Response 200:**
```json
{
  "photoId": "uuid",
  "processingStatus": "pending",
  "isExifValid": true,
  "isInsideGeofence": true,
  "isWithinTimeWindow": true
}
```

NSFW check ocurre async. Si falla, se notifica via push.

---

## 🏅 Badges

### GET /me/badges

Mi colección.

**Query params:**
- `category` (optional)
- `page`, `pageSize`

**Response 200:**
```json
{
  "badges": [
    {
      "id": "uuid",
      "serialNumber": 1247,
      "totalForEvent": 47832,
      "event": {
        "id": "uuid",
        "title": "World Tour 2026",
        "artist": "BTS",
        "venueName": "Estadio GNP Seguros",
        "city": "Ciudad de México",
        "category": "music",
        "startsAt": "2026-05-07T20:00:00-06:00"
      },
      "composedImageUrl": "https://...",
      "shareImageUrl": "https://...",
      "verificationScore": 92,
      "isVerified": true,
      "awardedAt": "2026-05-07T23:30:00Z"
    }
  ],
  "total": 23,
  "page": 1
}
```

### GET /badges/:id

Badge detail.

**Response 200:**
```json
{
  "id": "uuid",
  "serialNumber": 1247,
  "totalForEvent": 47832,
  "event": { /* Event partial */ },
  "user": {
    "handle": "moi",
    "displayName": "Moi"
  },
  "composedImageUrl": "https://...",
  "shareImageUrl": "https://...",
  "verificationScore": 92,
  "isVerified": true,
  "awardedAt": "2026-05-07T23:30:00Z",
  "verificationDetails": {
    "primarySource": "locus",
    "dwellMinutes": 215,
    "agreementScore": 0.94,
    "integrityVerdict": "trusted",
    "hasPhoto": true
  }
}
```

### GET /badges/:id/share

Returns share-optimized image URL (1080x1920) para Stories.

**Response 200:**
```json
{
  "shareImageUrl": "https://...",
  "shareText": "I was somewhere. @smwhr",
  "deepLink": "https://smwhr.quest/badge/uuid"
}
```

---

## 🌐 Public

### POST /waitlist

Landing waitlist signup.

**Request:**
```json
{
  "email": "user@example.com",
  "source": "landing",
  "referrer": "twitter",
  "interests": ["music", "festivals"]
}
```

**Response 200:**
```json
{
  "success": true,
  "message": "You're on the list. See you somewhere."
}
```

Si email ya existe, retorna success igual con mensaje "You're already on the list."

---

## 🚨 Error responses

Formato consistente de errores:

```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Handle must be 3-20 characters",
  "code": "INVALID_HANDLE",
  "timestamp": "2026-04-22T15:30:00Z",
  "path": "/me/onboarding"
}
```

### Códigos comunes

- `400 Bad Request` — validación falló
- `401 Unauthorized` — token inválido o expirado
- `403 Forbidden` — autenticado pero sin permisos
- `404 Not Found` — recurso no existe
- `409 Conflict` — duplicado (handle, intent, etc.)
- `422 Unprocessable Entity` — semánticamente inválido (ej: foto fuera de geofence)
- `429 Too Many Requests` — rate limited
- `500 Internal Server Error` — error del servidor

### Códigos custom relevantes

- `INVALID_HANDLE`
- `HANDLE_TAKEN`
- `EVENT_NOT_FOUND`
- `INTENT_ALREADY_EXISTS`
- `QUEST_NOT_ACTIVE`
- `OUTSIDE_GEOFENCE`
- `OUTSIDE_TIME_WINDOW`
- `INTEGRITY_FAILED`
- `PHOTO_NSFW_FLAGGED`
- `INSUFFICIENT_DWELL_TIME`

---

## 🔒 Rate limiting

- `POST /auth/*` — 10 req/min por IP
- `POST /events/:id/intent` — 30 req/min por user
- `POST /quests/:id/sync` — 60 req/min por user (cada 1 segundo)
- Otros endpoints — 100 req/min por user

Headers de respuesta:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`

---

## 📝 Notes para el frontend

### Almacenamiento de tokens

- `accessToken`: en memoria + flutter_secure_storage
- `refreshToken`: solo en flutter_secure_storage
- Refresh automático cuando access token expire (401 → refresh → retry)

### Pagination

- `page` 1-indexed
- `pageSize` máximo 100
- Response incluye `total` para calcular last page
- `hasMore` boolean opcional para infinite scroll

### Caching

- Events: cacheable 5 min en cliente
- Badges: cacheable 1 min
- User profile: refetch on app foreground
- Quest status: NUNCA cachear, siempre fresh

### Offline behavior

- Mobile encola sync de Locus events y geolocator pings en Hive si no hay red
- Cuando recupera red, batch upload de todo lo pendiente
- Backend debe ser idempotent en estos endpoints (recibir mismos events 2x no duplica)

---

*Este documento es el contrato. El frontend lo asume verdadero. El backend lo implementa para cumplirlo. Cambios requieren aprobación bilateral.*
