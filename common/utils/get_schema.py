import os
import json


def get_schema(schema: str) -> str:
    schema_dir = os.environ.get("DWH__SCHEMA_DIR", "/app/dwh/migrations/rp")
    schema_path = os.path.join(schema_dir, f"{schema}.json")

    with open(schema_path, "r") as f:
        return json.dumps(json.load(f))
