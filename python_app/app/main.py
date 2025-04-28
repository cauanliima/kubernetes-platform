from fastapi import FastAPI
import json
import os

app = FastAPI()

@app.on_event("startup")
def load_secrets():
    secrets_file = "/vault/secrets/json"  # Caminho fixo

    if not os.path.exists(secrets_file):
        raise FileNotFoundError(f"Secrets file not found: {secrets_file}")

    with open(secrets_file, "r") as f:
        secrets = json.load(f)

    for key, value in secrets.items():
        create_secret_endpoint(key, value)

def create_secret_endpoint(key: str, value: str):
    route = f"/{key.lower()}"

    async def endpoint():
        return {key: value}

    app.add_api_route(route, endpoint, methods=["GET"])

