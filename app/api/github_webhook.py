from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse

from app.security.github_signature import verify_github_signature

router = APIRouter()


@router.post("/webhooks/github")
async def github_webhook(request: Request) -> JSONResponse:
    settings = request.app.state.settings
    dispatcher = request.app.state.dispatcher
    rate_limiter = request.app.state.rate_limiter
    replay_protector = request.app.state.replay_protector

    delivery_id = request.headers.get("X-GitHub-Delivery", "")
    if not delivery_id:
        raise HTTPException(status_code=400, detail="missing_delivery_id")

    if settings.rate_limit_enabled:
        client_host = request.client.host if request.client else "unknown"
        if not rate_limiter.allow(client_host):
            raise HTTPException(status_code=429, detail="rate_limited")

    raw_body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256")

    if not verify_github_signature(settings.github_webhook_secret, raw_body, signature):
        raise HTTPException(status_code=401, detail="invalid_signature")

    if replay_protector.check_and_record(delivery_id):
        return JSONResponse(
            status_code=202,
            content={
                "accepted": False,
                "reason": "duplicate_delivery",
                "delivery_id": delivery_id,
                "dispatched": False,
            },
        )

    try:
        payload = json.loads(raw_body.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="invalid_json") from exc

    event = request.headers.get("X-GitHub-Event", "")

    result = await dispatcher.handle(event=event, delivery_id=delivery_id, payload=payload)

    status_code = 200
    if not result.accepted and result.reason.startswith("unsupported"):
        status_code = 202

    return JSONResponse(status_code=status_code, content=result.model_dump())
