# CALAMANDER SPECIFICATION (LOCKED)

**Date:** 2026-03-21  
**Status:** Ready for Implementation  
**Author:** David Griswold + Architecture Planning Session

---

## EXECUTIVE SUMMARY

Calamander is an AI scheduling assistant that converts email scheduling conversations into a guided scheduling experience. A sender clicks "Reply with Calamander" in Gmail, Calamander extracts scheduling context, returns an auto-drafted reply with a unique scheduling link, and the recipient uses that link to select a time from available slots. The meeting books to both calendars with Google Meet when appropriate. The same link allows unlimited rescheduling until the meeting occurs.

---

## PRODUCT PRINCIPLES

1. Single-purpose first (scheduling only)
2. Context-aware, not context-bloated
3. Hybrid interaction (chat + structured slots)
4. Mobile quality is mandatory
5. Low friction for recipients (no login)
6. Human-confirmed context before link creation
7. Timezones must be explicit
8. Slots should be constrained (3-5, prefer 5)
9. Rescheduling is simple (same link)
10. Security through lifecycle discipline

---

## CORE FLOW (LOCKED)

### Sender Flow
1. Sender is in Gmail thread
2. Sender clicks "Reply with Calamander" button (injected by extension)
3. Extension extracts thread text, sends to backend
4. Backend (async via Cloud Tasks):
   - Runs LLM extraction: purpose, duration, participants, timezone clues
   - Returns extracted context + auto-drafted reply
5. Extension shows draft to sender (can edit extracted fields)
6. Sender confirms → session created, scheduling link generated
7. Sender review and sends email with link

### Recipient Flow
1. Recipient clicks scheduling link in email
2. Frontend loads session via token
3. Recipient sees:
   - Meeting purpose/context (extracted summary)
   - Sender's name
   - Recipient's detected timezone
   - Available time slots (5 preferred, 3-5 acceptable)
   - Chat widget for guidance
4. Recipient selects a slot (or requests more options)
5. Backend re-checks availability in real time
6. Backend creates events on both calendars + generates Google Meet
7. Recipient sees confirmation + calendar invite sent
8. Same link allows unlimited reschedules until meeting occurs

### Rescheduling Flow
1. Recipient (or anyone with link) returns to same scheduling URL
2. Frontend detects existing meeting
3. Offers "Change time" option
4. Recipient selects new slot
5. Backend updates calendar event
6. Confirmation shown

---

## TECHNICAL STACK (LOCKED)

- **Frontend:** React/Vite (TypeScript), mobile-first
- **Backend:** Python/FastAPI
- **Data:** Firebase (Firestore for persistence)
- **Deployment:** GCP (Cloud Run, Terraform)
- **Gmail Integration:** Chrome extension (unpacked in V1)
- **LLM:** Claude Opus or GPT-4 (configurable)
- **Google APIs:** Calendar API, Meet link generation
- **Justfile:** Dev commands (dev, test, build, deploy)
- **New Repo:** Standalone (not in Amplify monorepo)

---

## SERVICE ARCHITECTURE

### Core Services

| Service | Purpose | Sync/Async |
|---------|---------|-----------|
| **Extraction** | Parse email, extract meeting context via LLM | Async (Cloud Tasks) |
| **Session** | Create/update/retrieve sessions, state machine | Sync |
| **Availability** | Query Google Calendar, generate slots | Sync (cached) |
| **Booking** | Create calendar events, generate Meet | Sync + retry |
| **Auth** | Google OAuth, token management | Sync |

### Backend Structure
```
backend/
├── services/
│   ├── extraction_service.py
│   ├── session_service.py
│   ├── availability_service.py
│   ├── booking_service.py
│   ├── auth_service.py
├── handlers/
│   ├── sender_handler.py
│   ├── recipient_handler.py
├── jobs/
│   └── extraction_job.py
├── models/
│   └── firestore_models.py
├── integrations/
│   ├── google_calendar.py
│   ├── google_meet.py
│   └── llm_client.py
└── utils/
    ├── token_generator.py
    └── timezone_utils.py
```

---

## DATA MODEL (FIRESTORE)

### Collections

**users/**
- userId, email, name, timezone, googleCalendarId, googleRefreshToken (encrypted), createdAt, updatedAt

**scheduling_sessions/**
- senderId, sessionToken (unique, 32 char), state (draft|open|scheduled|completed|cancelled)
- extractedContext (purpose, duration, timezone, additionalNotes)
- selectedSlot (start, end, timezone) — null until booked
- eventIds (senderCalendarEventId, recipientCalendarEventId)
- meetLink, expiresAt (30 days if not booked), createdAt, updatedAt

**calendar_connections/**
- userId, googleCalendarId, refreshToken (encrypted), accessToken (short-lived), tokenExpiresAt

**session_event_log/**
- sessionId, eventType (created|extracted|availability_queried|slot_selected|booked|rescheduled), timestamp, metadata

**slots_cache/** (TTL: 1 hour)
- sessionId_slots: slots array, createdAt

---

## API DESIGN

### Sender Routes (OAuth Required)

```
POST /api/v1/extract-draft
  Req: { threadId, threadText, senderEmail, senderName, recipientEmail, recipientName? }
  Res: { extractedContext, draftReply (Markdown), schedulingLink }

POST /api/v1/sessions/{sessionId}/confirm
  Req: { extractedContext (validated/edited) }
  Res: { sessionId, token, schedulingLink }
  State: draft → open

GET /api/v1/sessions/{sessionId}
  Res: { sessionId, state, extractedContext, selectedSlot, expiresAt }

POST /api/v1/sessions/{sessionId}/cancel
  Res: { sessionId, state: "cancelled" }
```

### Recipient Routes (Token-Based, No Login)

```
GET /api/v1/schedule/{sessionToken}
  Res: { sessionId, purpose, senderName, suggestedSlots, recipientTimezone, allowCustomDate }

POST /api/v1/schedule/{sessionToken}/book
  Req: { selectedSlot: {start, end, timezone}, recipientName, recipientEmail? }
  Res: { bookingConfirmation: {meetLink, calendarEventId}, message }

POST /api/v1/schedule/{sessionToken}/reschedule
  Req: { newSlot: {start, end, timezone} }
  Res: { bookingConfirmation: {...} }

GET /api/v1/schedule/{sessionToken}/slots
  Query: ?days=7&timezone=America/Denver
  Res: { suggestedSlots, lastRefreshed }

POST /api/v1/schedule/{sessionToken}/request-more-slots
  Req: { preferredDays?: array }
  Res: { slots: [...] }
```

---

## GMAIL EXTENSION

### Manifest
- Minimal permissions: identity, activeTab, scripting
- Host permissions: mail.google.com
- OAuth: calendar.readonly, gmail.readonly, email, profile

### Workflow
1. Content script injects "Reply with Calamander" button into compose area
2. User clicks button → popup opens
3. Popup extracts thread text (DOM scrape or Gmail API)
4. Calls `POST /api/v1/extract-draft`
5. Backend returns draft + link asynchronously
6. Popup displays draft in a modal (sender can edit fields)
7. Sender confirms → extension shows copy/insert instructions
8. Extension is unpacked in V1 (developer mode)

### Files
```
extension/
├── manifest.json
├── popup.html
├── popup.js (event listeners, API calls, UX)
├── content-script.js (inject button)
├── background.js (OAuth handling)
├── styles.css
└── config.js (API endpoint, feature flags)
```

---

## LLM EXTRACTION PIPELINE

### Prompt Design
Extract from email thread:
1. Meeting purpose/topic
2. Participant names & emails
3. Suggested duration (default 30 min if unclear)
4. Timezone clues (mentions of "EST", "my timezone", etc.)
5. Day/time constraints ("next week", "afternoons only")
6. Location preference (remote, in-person, unclear)
7. Any ambiguities or missing info

### Output Schema
```json
{
  "purpose": "string",
  "duration_minutes": 30,
  "participant_emails": ["recipient@example.com"],
  "participant_names": ["Alice"],
  "timezone_clues": "sender likely in EST, recipient location unknown",
  "day_constraints": "next week, weekdays only",
  "location_preference": "remote",
  "ambiguities": ["recipient timezone unclear"],
  "suggested_title": "string"
}
```

### Execution
- Async via Cloud Tasks (don't block sender UI)
- Called from `POST /api/v1/extract-draft`
- Result stored in session before returning to extension
- Sender sees extracted context in confirmation modal

---

## AVAILABILITY GENERATION

### Google Calendar Query
- Query sender's calendar for next 7 days (configurable window)
- Default working hours: 9am–6pm (sender's timezone)
- Find 30-min slots (or duration from extraction)
- Default: 5 slots, min 3, max 5
- Group by day for readability

### Caching
- Cache slots for 5 minutes per session
- `request-more-slots` clears cache and re-queries
- Slots cache in Firestore with 1-hour TTL

### Slot Freshness
- Before booking, re-check availability
- If slot taken (race condition): offer alternatives

---

## TIMEZONE HANDLING

### Precedence
1. **Explicit sender instruction** (thread says "EST" or sender confirms "Eastern")
2. Sender's Google Calendar timezone
3. Recipient's browser-detected timezone
4. Default UTC

### Display
- Always label times with timezone: "2:00 PM Eastern"
- Recipient can override timezone with manual picker
- Detect timezone from browser (timezone API)

---

## BOOKING & CALENDAR INTEGRATION

### Google Calendar Event Creation
- Organizer: sender's email
- Attendees: sender, recipient
- Title: from extraction
- Description: extracted context summary
- Meet link: auto-added (hangoutsMeet conference type)
- Both parties receive calendar invite

### Meet Link Handling
- If Meet generation fails:
  - Create event without Meet
  - Email you (david@calamander.dev) alert
  - Recipient sees "Meeting scheduled" (check email)
  - You can manually add Zoom or re-send with Meet link

### Rescheduling
- Update original calendar event (preserve history)
- Keep eventId same
- Recalculate timezones if recipient's timezone changed

---

## STATE MACHINE

```
Draft → Open → Scheduled → Completed
    ↘ Cancelled

Rescheduling:
Scheduled → Scheduled (event updated, link remains valid)

Expiration:
Open (unpicked) → Expired (after 30 days)
Scheduled → Completed (meeting time has passed)
Completed/Expired → Link no longer books (read-only rescheduling or 410)
```

---

## ERROR HANDLING

| Scenario | Behavior |
|----------|----------|
| Slot taken at booking | Offer 3-5 alternatives immediately |
| Calendar API timeout | Retry 3x with exponential backoff, then error |
| Meet generation fails | Create event without Meet, alert David |
| Invalid/expired token | 410 Gone |
| Timezone conflict (thread vs browser) | Show confirmation modal, let recipient pick |
| OAuth token refresh fails | Return 401, sender re-auths |
| LLM extraction fails | Return 500, log to Sentry/Cloud Logging |

---

## SECURITY & PRIVACY

- **Session tokens:** Generated via `secrets.token_urlsafe(24)`, stored in Firestore
- **Recipient access:** Token-based (no login)
- **Refresh tokens:** Encrypted at rest (Cloud KMS)
- **Access tokens:** Cached in-process, short-lived
- **Raw thread:** Not stored by default (data minimization)
- **Link lifecycle:** 
  - Valid for 30 days if unscheduled
  - Valid for rescheduling until meeting occurs
  - Expires (410) after meeting end time
- **Forwarded links:** Truly public (no recipient identity check) — mitigated by expiration

---

## GMAIL EXTENSION DISTRIBUTION

### V1 (MVP)
- Unpacked/developer mode
- You manually enable in Chrome extensions
- Full control, no review
- Fast iteration

### V2+ (When scaling)
- Chrome Web Store submission
- Privacy policy required
- 1-2 week review
- Auto-updates
- $5 one-time fee

---

## DEPLOYMENT

### Infrastructure
- **API:** Cloud Run (FastAPI)
- **Async jobs:** Cloud Tasks (extraction, notifications)
- **Database:** Firestore
- **Secrets:** Cloud Secret Manager (encrypted tokens)
- **Logging:** Cloud Logging + Sentry
- **Monitoring:** Cloud Monitoring + Datadog

### Terraform Structure
```
terraform/
├── main.tf (Cloud Run, Firestore, Cloud Tasks)
├── secrets.tf (Secret Manager)
├── variables.tf
├── outputs.tf
└── environments/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

### Environment Variables
```
CALAMANDER_API_URL=https://api.calamander.dev
CALAMANDER_FRONTEND_URL=https://calamander.dev
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=... (via Secret Manager)
LLM_API_KEY=... (Claude or OpenAI)
LLM_MODEL=claude-opus-4
FIREBASE_PROJECT_ID=calamander-dev
```

---

## JUSTFILE

```justfile
@default:
  just --list

# Development
@dev:
  cd backend && python -m uvicorn main:app --reload

@test:
  cd backend && pytest -v

@test-watch:
  ptw backend/

# Building
@build-backend:
  cd backend && docker build -t calamander-api:latest .

@build-extension:
  cd extension && npm run build

@build-frontend:
  cd frontend && npm run build

# Deployment
@deploy-dev:
  terraform -chdir=terraform apply -var-file=environments/dev.tfvars

@deploy-prod:
  terraform -chdir=terraform apply -var-file=environments/prod.tfvars

# Utilities
@format:
  cd backend && black .
  cd frontend && npm run format

@lint:
  cd backend && flake8 .
  cd frontend && npm run lint
```

---

## V1 SCOPE

### Included
- Manual sender creation page (or Gmail extension)
- LLM extraction of scheduling context
- Confirmation/edit modal
- Scheduling session creation + link generation
- Recipient-facing scheduling page (mobile-friendly)
- 5 available slots (or 3-5 as needed)
- "Request more options" flow
- Timezone visibility + auto-detection
- Google Calendar event creation + Meet generation
- Rescheduling via same link (unlimited)
- Link expiration after meeting occurs

### Deferred to V2+
- Gmail add-on (Chrome Store)
- Dashboard (see your sessions)
- Email notifications/reminders
- Full recurrence support
- Multi-calendar selection
- Advanced availability rules

---

## SUCCESS CRITERIA

1. Sender can generate scheduling link in <2 minutes
2. Extracted context is accurate (sender confirms with confidence)
3. Recipient can schedule from phone with minimal friction
4. Timezone handled clearly throughout
5. Recipient sees 5 obvious time options
6. Meeting created in both calendars automatically
7. Same link allows rescheduling before meeting occurs
8. Feels more context-aware than generic scheduling tools

---

## IMPLEMENTATION ROADMAP

### Phase 1: Backend Foundation
- [ ] Firestore schema + indexes
- [ ] User auth service (Google OAuth)
- [ ] Session service (CRUD, state machine)
- [ ] LLM extraction service
- [ ] Unit tests

### Phase 2: Calendar Integration
- [ ] Google Calendar querying
- [ ] Availability generation
- [ ] Event creation + Meet link
- [ ] Rescheduling logic
- [ ] Integration tests

### Phase 3: Frontend + Extension
- [ ] React recipient UI (slots + chat)
- [ ] Gmail extension (minimal)
- [ ] End-to-end flow testing

### Phase 4: Polish & Deploy
- [ ] Performance optimization
- [ ] Error handling + edge cases
- [ ] Logging + monitoring
- [ ] Terraform + Cloud Run deployment
- [ ] Private beta testing

---

## DECISIONS LOCKED

✅ Gmail extension (unpacked in V1)  
✅ No recipient login (token-based)  
✅ Sender auth required (Google Calendar)  
✅ Unlimited reschedules  
✅ Explicit timezone instruction overrides detection  
✅ Meet link failure → create event without, email David  
✅ Async LLM extraction (don't block sender)  
✅ 5 slots default (3-5 range)  
✅ Firestore for persistence  
✅ Multi-user schema from day one  
✅ Cloud Run + Terraform deployment  

---

## NEXT STEP

Build Phase 1 (backend foundation + schema).

