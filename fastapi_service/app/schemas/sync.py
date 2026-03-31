from pydantic import BaseModel
from typing import Any

class SyncRequest(BaseModel):
    last_sync_at: str
    entities: dict[str, list[dict[str, Any]]]

class SyncResponse(BaseModel):
    conflicts: list[dict[str, Any]]
    updated_entities: list[dict[str, Any]]
