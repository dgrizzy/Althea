# PMS Cache Operationalization Spec

**Status:** Locked  
**Date:** 2026-03-20  
**Author:** David Griswold + Planning Session  

---

## Vision

Operationalize the PMS abstraction layer by centralizing all PMS data access through Firebase caching with intelligent refresh jobs. Routes query Firestore directly with TTL-based freshness validation. When data expires, requests block while a background refresh job syncs delta changes from OpenDental (via DateTStamp) back to Firestore. A daily audit job verifies data consistency and alerts on any count mismatches.

---

## Scope

### In
- [ ] Firestore models with TTL + last_synced + audit fields
- [ ] APScheduler-based refresh jobs (per-location, smart queue deduplication)
- [ ] Delta sync via OpenDental DateTStamp parameter
- [ ] Block-on-stale pattern: route queues refresh, waits, returns fresh
- [ ] Daily audit job: count verification + spot checks (5% sample)
- [ ] Stale fallback: PMS down → serve stale + warning response
- [ ] Mock data externalized to YAML (per-location files)
- [ ] TTL configuration per object type (patients, appointments, clinicians, etc.)
- [ ] Integration tests with demo data + refresh verification
- [ ] **Consolidate `/practice/directory` to read from cached PMS data** (not practice_directory collection)
- [ ] Update PracticeDirectoryRepository (or replace with cache_reader helper)

### Out
- [ ] Separate PMS service (routes hit Firestore + refresh jobs directly)
- [ ] Real-time sync (batch refresh jobs, not streaming)
- [ ] Deletion tracking from OpenDental (OpenDental API doesn't support it)
- [ ] Complex conflict resolution (assume Firestore is stale, always trust PMS on refresh)

---

## Architecture

### Data Flow

```
Route receives request
  ↓
Check Firestore record TTL
  ├─ Valid (not expired)
  │  └─ Return data (fresh path)
  │
  └─ Expired or missing
     ↓
     Queue refresh job for location
     ↓
     Wait for job to complete (block)
     ├─ Success
     │  └─ Return fresh Firestore data
     │
     └─ PMS unavailable
        └─ Return stale Firestore data + warning header
```

### Refresh Job Flow

```
RefreshJob(location_slug)
  ↓
Check dedup queue: is another job for this location in-flight?
  ├─ Yes → Wait for existing job, return result
  └─ No  → Proceed
  ↓
Get last_sync_timestamp from Firestore metadata
  ↓
Query OpenDental: GET /patients/Simple?DateTStamp={timestamp}
  ├─ With pagination (max 100 per request)
  ├─ Retry on rate-limit (exponential backoff)
  │
  ├─ Success
  │  ├─ Merge results into Firestore (upsert)
  │  ├─ Update last_sync_timestamp
  │  ├─ Update sync_checksum (MD5 of all records)
  │  └─ Return "refreshed"
  │
  └─ PMS error
     ├─ Log error
     └─ Return "failed" (caller decides to serve stale)
```

### Components

#### 1. Firestore Models

**Base model (all cached objects inherit):**
```python
# libs/amplify/core/db/models/cache.py
class CachedEntity(BaseModel):
    """Base for all PMS-sourced entities in Firestore."""
    id: str  # Amplify UUID
    pms_id: str  # OpenDental PatNum, AptNum, etc.
    
    # Cache metadata
    ttl_seconds: int  # Type-specific TTL
    last_synced_at: datetime  # Last successful PMS sync
    sync_source: str  # "opendental", "demo", etc.
    sync_checksum: Optional[str] = None  # Hash for audit
    
    # Audit fields
    created_at: datetime
    updated_at: datetime
```

**Patient model:**
```python
class CachedPatient(CachedEntity):
    location_id: str
    first_name: str
    last_name: str
    email: Optional[str]
    phone: Optional[str]
    date_of_birth: Optional[date]
    
    @property
    def is_stale(self) -> bool:
        return (datetime.utcnow() - self.last_synced_at).total_seconds() > self.ttl_seconds
```

**Appointment, Clinician models — similar pattern**

#### 2. TTL Configuration

```python
# apps/amplify_api/config.py
PMS_CACHE_TTL = {
    "patient": 3600,           # 1 hour
    "appointment": 900,         # 15 minutes
    "clinician": 14400,         # 4 hours
    "operatory": 86400,         # 1 day
}
```

Can be overridden via environment:
```
PMS_CACHE_TTL_PATIENT=1800
```

#### 3. Refresh Queue + Deduplication

```python
# apps/amplify_api/pms/refresh_queue.py
from asyncio import Event
from typing import Dict, Coroutine

class RefreshQueue:
    """Smart queue that deduplicates concurrent refresh requests."""
    
    def __init__(self):
        self._in_flight: Dict[str, Coroutine] = {}
        self._lock = asyncio.Lock()
    
    async def enqueue_or_wait(
        self, 
        location_id: str, 
        job_coro: Coroutine
    ) -> Any:
        """Enqueue job. If already in-flight, wait for existing."""
        async with self._lock:
            if location_id in self._in_flight:
                existing = self._in_flight[location_id]
            else:
                existing = asyncio.create_task(job_coro)
                self._in_flight[location_id] = existing
        
        try:
            return await existing
        finally:
            async with self._lock:
                if self._in_flight.get(location_id) is existing:
                    del self._in_flight[location_id]
```

#### 4. Refresh Jobs (APScheduler)

```python
# apps/amplify_api/pms/refresh_jobs.py
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime, timedelta

class PMSRefreshScheduler:
    def __init__(self, pms_pool, firestore_client, refresh_queue):
        self.pms_pool = pms_pool
        self.firestore = firestore_client
        self.queue = refresh_queue
        self.scheduler = AsyncIOScheduler()
    
    async def refresh_location(self, location_id: str) -> Dict[str, Any]:
        """Sync delta changes from PMS → Firestore."""
        logger.info(f"Refresh job starting: location={location_id}")
        
        try:
            # Get last sync timestamp
            metadata = await self.firestore.get(
                f"pms_metadata/{location_id}"
            )
            last_sync = metadata.get("last_synced_at", datetime(1970, 1, 1))
            
            # Get PMS client
            client = await self.pms_pool.get_client(location_id)
            
            # Fetch delta patients
            all_patients = []
            offset = 0
            while True:
                batch = await client.search_patients_since(
                    since=last_sync,
                    limit=100,
                    offset=offset
                )
                if not batch:
                    break
                all_patients.extend(batch)
                offset += len(batch)
                if len(batch) < 100:
                    break
            
            # Upsert to Firestore
            batch_write = self.firestore.batch()
            for patient in all_patients:
                cached = CachedPatient(
                    id=patient.id,
                    pms_id=patient.pms_patient_id,
                    ttl_seconds=PMS_CACHE_TTL["patient"],
                    last_synced_at=datetime.utcnow(),
                    location_id=location_id,
                    **patient.dict()
                )
                batch_write.set(
                    f"patients/{location_id}/{patient.id}",
                    cached.dict()
                )
            await batch_write.commit()
            
            # Update metadata
            await self.firestore.set(
                f"pms_metadata/{location_id}",
                {
                    "last_synced_at": datetime.utcnow(),
                    "sync_count": len(all_patients),
                    "sync_status": "success"
                }
            )
            
            logger.info(f"Refresh complete: location={location_id}, count={len(all_patients)}")
            return {"status": "success", "synced_count": len(all_patients)}
        
        except Exception as e:
            logger.error(f"Refresh failed: location={location_id}, error={e}")
            return {"status": "failed", "error": str(e)}
    
    async def audit_location(self, location_id: str) -> Dict[str, Any]:
        """Daily audit: verify counts + sample 5% of records."""
        logger.info(f"Audit job starting: location={location_id}")
        
        alerts = []
        
        try:
            client = await self.pms_pool.get_client(location_id)
            
            # Get counts from PMS
            pms_patient_count = await client.count_patients()
            
            # Get counts from Firestore
            fs_patients = await self.firestore.collection(
                f"patients/{location_id}"
            ).count().get()
            fs_count = fs_patients.size
            
            # Alert on mismatch (any difference)
            if pms_patient_count != fs_count:
                msg = f"Patient count mismatch: PMS={pms_patient_count} FS={fs_count}"
                logger.warning(msg)
                alerts.append(msg)
            
            # Spot-check 5% of Firestore records
            all_fs = await self.firestore.collection(
                f"patients/{location_id}"
            ).stream()
            sample_size = max(1, len(list(all_fs)) // 20)  # 5%
            
            for i, fs_doc in enumerate(all_fs):
                if i % 20 != 0:
                    continue  # Sample every 20th
                
                fs_patient = fs_doc.to_dict()
                pms_patient = await client.get_patient(fs_doc.id)
                
                # Compare key fields
                if fs_patient["last_name"] != pms_patient.last_name:
                    alerts.append(f"Data mismatch: patient {fs_doc.id} name")
            
            if alerts:
                logger.error(f"Audit alerts for {location_id}: {alerts}")
                # TODO: Send alert (Slack, email, etc.)
            
            return {"status": "success", "alerts": alerts}
        
        except Exception as e:
            logger.error(f"Audit failed: location={location_id}, error={e}")
            return {"status": "failed", "error": str(e)}
    
    def start(self):
        """Start scheduler with refresh + audit jobs."""
        # Per-location refresh job (runs on-demand, queued from routes)
        # No scheduled trigger — triggered by RefreshQueue.enqueue_or_wait()
        
        # Daily audit job (midnight UTC)
        self.scheduler.add_job(
            func=self._audit_all_locations,
            trigger=CronTrigger(hour=0, minute=0),
            id="daily_pms_audit",
            replace_existing=True
        )
        
        self.scheduler.start()
        logger.info("PMS refresh scheduler started")
    
    async def _audit_all_locations(self):
        """Audit all configured locations."""
        config = FilePMSConfigProvider()
        for location_slug in config.get_location_slugs():
            await self.audit_location(location_slug)
```

#### 5. Route Integration

**New consolidated pattern:** All routes reading PMS data (patients, clinicians, operatories) use this helper:

```python
# apps/amplify_api/pms/cache_reader.py
async def ensure_fresh_cache(
    location_id: str,
    data_type: str,  # "patients", "clinicians", "operatories"
    firestore: Client,
    queue: RefreshQueue,
    scheduler: PMSRefreshScheduler
) -> tuple[List[Dict], Optional[str]]:
    """
    Read from Firestore cache. If stale, block + refresh. If PMS down, serve stale.
    
    Returns: (data_list, warning_message_or_none)
    """
    docs = await firestore.collection(
        f"{data_type}/{location_id}"
    ).stream()
    
    data = [doc.to_dict() for doc in docs]
    
    # Check if ANY document is stale
    stale_docs = [d for d in data if d.get("is_stale")]
    
    if stale_docs:
        # Queue + wait for refresh
        refresh_job = scheduler.refresh_location(location_id)
        result = await queue.enqueue_or_wait(location_id, refresh_job)
        
        if result["status"] == "failed":
            # PMS is down, serve stale + warning
            logger.warning(f"PMS unavailable, serving stale {data_type} for {location_id}")
            return data, "Data may be stale (PMS unavailable)"
    
    # Return fresh data
    return data, None


# apps/amplify_api/routes/practice_directory.py
from fastapi import APIRouter, Depends, Query
from amplify_api.pms.cache_reader import ensure_fresh_cache

router = APIRouter(prefix="/practice", tags=["practice"])

@router.get(
    "/directory",
    response_model=PracticeDirectoryResponse,
    summary="Get practice directory (from cached PMS data)",
)
async def get_practice_directory(
    user: Dict[str, Any] = Depends(get_current_user),
    location_id: Optional[str] = Query(None),
    firestore: Client = Depends(get_firestore),
    queue: RefreshQueue = Depends(get_refresh_queue),
    scheduler: PMSRefreshScheduler = Depends(get_refresh_scheduler),
) -> PracticeDirectoryResponse:
    """
    Return practice directory (patients, providers, operatories, support_staff).
    
    BREAKING CHANGE: Now reads from cached PMS data (patients/{location_id}, etc)
    instead of practice_directory collection. Single source of truth is PMS via cache.
    
    Data is blocked if stale; will refresh from PMS and return fresh.
    If PMS unavailable, serves stale with warning header.
    """
    uid = user.get("uid", "")
    location_id = location_id or "default"
    
    logger.info("Fetching practice directory (cached PMS) for uid=%s location_id=%s", uid, location_id)
    
    # Fetch from cache (blocks if stale, refreshes PMS)
    patients_data, patients_warning = await ensure_fresh_cache(
        location_id, "patients", firestore, queue, scheduler
    )
    clinicians_data, clinicians_warning = await ensure_fresh_cache(
        location_id, "clinicians", firestore, queue, scheduler
    )
    operatories_data, operatories_warning = await ensure_fresh_cache(
        location_id, "operatories", firestore, queue, scheduler
    )
    
    # Aggregate warnings
    warning = patients_warning or clinicians_warning or operatories_warning
    
    # Format response (transform cached data to DirectoryEntry format)
    patients = [
        DirectoryEntryResponse(
            id=p["id"],
            category="patient",
            name=f"{p.get('first_name', '')} {p.get('last_name', '')}".strip(),
        )
        for p in patients_data
    ]
    
    providers = [
        DirectoryEntryResponse(
            id=c["id"],
            category="provider",
            name=f"{c.get('first_name', '')} {c.get('last_name', '')}".strip(),
            role=c.get("license"),
        )
        for c in clinicians_data
    ]
    
    operatories = [
        DirectoryEntryResponse(
            id=o["id"],
            category="operatory",
            name=o.get("name", ""),
        )
        for o in operatories_data
    ]
    
    # Support staff — not currently in PMS cache, leave empty for now
    support_staff = []
    
    response = PracticeDirectoryResponse(
        patients=patients,
        providers=providers,
        operatories=operatories,
        support_staff=support_staff,
    )
    
    # If there was a warning, add to response headers
    if warning:
        # Could also return warning in response body if needed
        logger.warning(f"PMS data stale for {location_id}: {warning}")
    
    return response
```

**UI client remains unchanged** — `/practice/directory` API contract stays the same, only the data source moves from manual seeding to PMS-cached + auto-refreshed.

#### 6. FastAPI Startup/Lifespan

```python
# apps/amplify_api/main.py
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    config = FilePMSConfigProvider()
    pms_pool = await PMSClientPool.initialize(config)
    refresh_queue = RefreshQueue()
    scheduler = PMSRefreshScheduler(pms_pool, firestore_client, refresh_queue)
    
    app.state.pms_pool = pms_pool
    app.state.refresh_queue = refresh_queue
    app.state.refresh_scheduler = scheduler
    
    scheduler.start()
    logger.info("PMS cache system initialized")
    
    yield
    
    # Shutdown
    scheduler.scheduler.shutdown()
    await pms_pool.close()
    logger.info("PMS cache system shut down")

app = FastAPI(lifespan=lifespan)
```

---

## Demo Data (YAML)

**File structure:**
```
configs/demo_data/
├── lakeview.yaml
└── downtown.yaml
```

**Example: lakeview.yaml**
```yaml
location:
  slug: lakeview
  name: Lakeview Dental
  location_id: "00000000-0000-0000-0000-000000000001"

patients:
  - id: "10000000-0000-0000-0000-000000000001"
    first_name: "Sarah"
    last_name: "Johnson"
    email: "sarah@example.com"
    phone: "303-555-0101"
    date_of_birth: "1985-03-15"
    pms_id: "P001"
    
  - id: "10000000-0000-0000-0000-000000000002"
    first_name: "Michael"
    last_name: "Chen"
    email: "michael@example.com"
    phone: "303-555-0102"
    date_of_birth: "1992-07-22"
    pms_id: "P002"

appointments:
  - id: "20000000-0000-0000-0000-000000000001"
    patient_id: "10000000-0000-0000-0000-000000000001"
    pms_id: "A001"
    scheduled_at: "2026-03-22T09:00:00Z"
    status: "scheduled"
    appointment_type: "cleaning"
    clinician_id: "30000000-0000-0000-0000-000000000001"
    
  - id: "20000000-0000-0000-0000-000000000002"
    patient_id: "10000000-0000-0000-0000-000000000002"
    pms_id: "A002"
    scheduled_at: "2026-03-23T10:30:00Z"
    status: "scheduled"
    appointment_type: "exam"
    clinician_id: "30000000-0000-0000-0000-000000000001"

clinicians:
  - id: "30000000-0000-0000-0000-000000000001"
    first_name: "Dr."
    last_name: "Smith"
    pms_id: "DR001"
    license: "CO-DEN-12345"
```

---

## Integration Tests

### Test 1: Stale Cache → Refresh → Fresh Data
```python
@pytest.mark.asyncio
async def test_stale_cache_triggers_refresh(test_app, test_scheduler):
    # Seed Firestore with stale patient (expired TTL)
    old_patient = {
        "id": "P1", 
        "first_name": "John",
        "ttl_seconds": 3600,
        "last_synced_at": datetime.utcnow() - timedelta(hours=2)
    }
    firestore.set("patients/demo/P1", old_patient)
    
    # Mock PMS to return updated patient
    mock_pms.get_patient.return_value = Patient(
        id="P1", 
        first_name="John Updated"
    )
    
    # Call route
    response = client.get("/practice/demo/patients")
    
    # Verify refresh happened + fresh data returned
    assert response.status_code == 200
    assert response.json()["data"][0]["first_name"] == "John Updated"
    assert response.json()["warning"] is None
```

### Test 2: PMS Down → Serve Stale + Warning
```python
@pytest.mark.asyncio
async def test_pms_down_serves_stale(test_app):
    # Seed Firestore with stale patient
    old_patient = {...}
    firestore.set("patients/demo/P1", old_patient)
    
    # Mock PMS to be unavailable
    mock_pms.get_patient.side_effect = PMSConnectionError()
    
    # Call route
    response = client.get("/practice/demo/patients")
    
    # Verify stale data returned with warning
    assert response.status_code == 200
    assert response.json()["warning"] == "Data may be stale (PMS unavailable)"
    assert len(response.json()["data"]) > 0
```

### Test 3: Daily Audit Detects Count Mismatch
```python
@pytest.mark.asyncio
async def test_daily_audit_alerts_on_mismatch(test_scheduler):
    # Seed Firestore with 5 patients
    # Mock OpenDental to return 6 patients
    
    # Run audit
    result = await test_scheduler.audit_location("demo")
    
    # Verify alert generated
    assert result["status"] == "success"
    assert len(result["alerts"]) > 0
    assert "count mismatch" in result["alerts"][0].lower()
```

---

## Risks and Unknowns

### Risks
- **OpenDental API rate limits:** If refresh jobs hammer the API, will get throttled. **Mitigation:** Exponential backoff + per-location deduplication queue.
- **Firestore write hotspot:** If many refresh jobs write to same location simultaneously. **Mitigation:** Dedup queue ensures only one job per location.
- **Stale data serving:** If PMS is down for extended time, users see old data. **Mitigation:** Warning header alerts users; audit job will detect mismatch and alert ops.

### Unknowns
- **OpenDental DateTStamp performance:** Unknown if querying with old timestamp is slow. **How we'll learn:** Implement + benchmark first refresh pull.
- **Spot-check effectiveness:** Is 5% sample enough to catch data corruption? **How we'll learn:** Run audit in shadow mode first, compare against manual spot checks.
- **Block-on-stale UX:** Will users tolerate 2-3 second wait for refresh? **How we'll learn:** Monitor request latency + user feedback.

---

## Implementation Breakdown

### Phase 1: Foundation (Days 1-2)
1. [ ] Create CachedEntity + CachedPatient + CachedClinician Firestore models
2. [ ] Add TTL config to app settings
3. [ ] Implement RefreshQueue with deduplication
4. [ ] Implement refresh_location job logic (fetch + upsert)
5. [ ] Add unit tests for queue + job logic

### Phase 2: Integration (Days 3-4)
1. [ ] Wire APScheduler into FastAPI lifespan
2. [ ] Implement audit_location job
3. [ ] Implement ensure_fresh_cache helper
4. [ ] Refactor `/practice/directory` to read from cached PMS data
5. [ ] Add integration tests (stale → refresh, PMS down)

### Phase 3: Demo & Iteration (Days 5)
1. [ ] Load demo YAML data on startup (patients, clinicians, operatories)
2. [ ] Test end-to-end flow: `/practice/directory` hits cache + refreshes from demo/OpenDental
3. [ ] Verify audit job runs daily
4. [ ] Performance benchmarking (refresh latency, Firestore write cost)
5. [ ] Documentation + runbook

---

## Notes

- **Firestore write cost:** Expect ~100 writes per location per refresh. Budget accordingly for production.
- **Clock skew:** Ensure server clock is synced (NTP) for accurate TTL validation.
- **Future work:** Add webhooks from OpenDental instead of polling (if supported).
- **Delta limitations:** OpenDental API doesn't track deletes, so deleted patients won't sync. Handle via separate cleanup job if needed.

