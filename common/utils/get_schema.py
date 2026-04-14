import os
import json


def get_schema(schema: str) -> str:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    schema_path = os.path.join(base_dir, "../../dwh/migrations/rp", f"{schema}.json")

    with open(schema_path, "r") as f:
        return json.dumps(json.load(f))
