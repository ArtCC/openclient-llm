# Running LiteLLM with Docker

This guide shows how to self-host [LiteLLM](https://docs.litellm.ai) as an OpenAI-compatible proxy using Docker Compose so you can use it as a backend with OpenClient LLM. It covers the full stack: Postgres for persistence, Traefik as a reverse proxy, a reference `config.yaml` with both local (Ollama) and cloud models, and common operational commands.

## Reference

- https://docs.litellm.ai/docs/proxy/deploy
- https://docs.litellm.ai/docs/proxy/configs
- https://github.com/BerriAI/litellm

## docker-compose.yml

```yaml
services:
  litellm-db:
    image: postgres:16-alpine
    container_name: litellm-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: litellm
    volumes:
      - /opt/docker/litellm/pgdata:/var/lib/postgresql/data
    networks:
      - proxy
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm -d litellm"]
      interval: 10s
      timeout: 5s
      retries: 5

  litellm:
    image: docker.litellm.ai/berriai/litellm-database:main-stable
    container_name: litellm
    restart: unless-stopped
    depends_on:
      litellm-db:
        condition: service_healthy
    volumes:
      - /opt/docker/litellm/config.yaml:/app/config.yaml
    ports:
      - "4000:4000"
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.litellm.rule=Host(`litellm.yourdomain.com`)"
      - "traefik.http.routers.litellm.entrypoints=websecure"
      - "traefik.http.routers.litellm.tls.certresolver=le"
      - "traefik.http.services.litellm.loadbalancer.server.port=4000"
    environment:
      LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY}
      DATABASE_URL: ${DATABASE_URL}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      GOOGLE_API_KEY: ${GOOGLE_API_KEY}
      DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY}
      FIRECRAWL_API_KEY: ${FIRECRAWL_API_KEY}
      BRAVE_API_KEY: ${BRAVE_API_KEY}
    command: ["--config", "/app/config.yaml", "--port", "4000"]
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  proxy:
    external: true
```

## Reference .env

```env
LITELLM_MASTER_KEY=sk-your-master-key
POSTGRES_PASSWORD=your-postgres-password
DATABASE_URL=postgresql://litellm:your-postgres-password@litellm-db:5432/litellm
OPENAI_API_KEY=your-openai-api-key
ANTHROPIC_API_KEY=your-anthropic-api-key
GOOGLE_API_KEY=your-google-api-key
DEEPSEEK_API_KEY=your-deepseek-api-key
FIRECRAWL_API_KEY=your-firecrawl-api-key
BRAVE_API_KEY=your-brave-api-key
```

## Reference config.yaml

Create at `/opt/docker/litellm/config.yaml`:

```yaml
model_list:
  # Ollama — Google
  - model_name: gemma4:e4b
    litellm_params:
      model: ollama/gemma4:e4b
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: true
      supports_function_calling: false

  - model_name: gemma3:12b
    litellm_params:
      model: ollama/gemma3:12b
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: true
      supports_function_calling: false

  # Ollama — Qwen (Alibaba)
  - model_name: qwen3:14b
    litellm_params:
      model: ollama/qwen3:14b
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: false
      supports_function_calling: true

  - model_name: qwen3.5:cloud
    litellm_params:
      model: ollama/qwen3.5:cloud
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: false
      supports_function_calling: true

  - model_name: qwen2.5-coder:14b
    litellm_params:
      model: ollama/qwen2.5-coder:14b
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: false
      supports_function_calling: true

  - model_name: qwen3-coder:480b-cloud
    litellm_params:
      model: ollama/qwen3-coder:480b-cloud
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: false
      supports_function_calling: true

  - model_name: qwen3-coder-next:cloud
    litellm_params:
      model: ollama/qwen3-coder-next:cloud
      api_base: http://host.docker.internal:11434
    model_info:
      supports_vision: false
      supports_function_calling: true

  # APIs cloud
  # OpenAI
  - model_name: gpt-5.4
    litellm_params:
      model: openai/gpt-5.4
      api_key: os.environ/OPENAI_API_KEY

  - model_name: gpt-5.4-mini
    litellm_params:
      model: openai/gpt-5.4-mini
      api_key: os.environ/OPENAI_API_KEY

  - model_name: gpt-5.4-nano
    litellm_params:
      model: openai/gpt-5.4-nano
      api_key: os.environ/OPENAI_API_KEY

  - model_name: gpt-4o-mini-tts
    litellm_params:
      model: openai/gpt-4o-mini-tts
      api_key: os.environ/OPENAI_API_KEY

  - model_name: gpt-4o-mini-transcribe
    litellm_params:
      model: openai/gpt-4o-mini-transcribe
      api_key: os.environ/OPENAI_API_KEY

  # Anthropic
  - model_name: claude-opus-4-6
    litellm_params:
      model: anthropic/claude-opus-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-sonnet-4-6
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-haiku-4-5
    litellm_params:
      model: anthropic/claude-haiku-4-5
      api_key: os.environ/ANTHROPIC_API_KEY

  # Google
  - model_name: gemini-3.1-pro-preview
    litellm_params:
      model: gemini/gemini-3.1-pro-preview
      api_key: os.environ/GOOGLE_API_KEY

  - model_name: gemini-3-pro-image-preview
    litellm_params:
      model: gemini/gemini-3-pro-image-preview
      api_key: os.environ/GOOGLE_API_KEY

  - model_name: gemini-2.5-pro
    litellm_params:
      model: gemini/gemini-2.5-pro
      api_key: os.environ/GOOGLE_API_KEY

  # DeepSeek
  - model_name: deepseek-chat
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY

  - model_name: deepseek-reasoner
    litellm_params:
      model: deepseek/deepseek-reasoner
      api_key: os.environ/DEEPSEEK_API_KEY

search_tools:
  - search_tool_name: brave-search
    litellm_params:
      search_provider: brave
      api_key: os.environ/BRAVE_API_KEY

  - search_tool_name: firecrawl-search
    litellm_params:
      search_provider: firecrawl
      api_key: os.environ/FIRECRAWL_API_KEY

  - search_tool_name: searxng-search
    litellm_params:
      search_provider: searxng
      api_base: https://search.rhscz.eu

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
```

## Operational notes

Prepare the data directory:

```bash
sudo mkdir -p /opt/docker/litellm
sudo chown -R 1000:1000 /opt/docker/litellm
```

Create the configuration file:

```bash
sudo nano /opt/docker/litellm/config.yaml
```

Start the service:

```bash
docker compose up -d
```

Verify the proxy is running:

```bash
curl http://localhost:4000/health
```

List available models:

```bash
curl http://localhost:4000/models \
  -H "Authorization: Bearer sk-your-master-key"
```

Test a chat completion against a local model:

```bash
curl http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-master-key" \
  -d '{
    "model": "qwen3:14b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

Internal DNS (e.g. Pi-hole):

- `litellm.yourdomain.com` → `192.168.x.x`

## Notes

- `LITELLM_MASTER_KEY` must start with `sk-`. Generate one with:

```bash
echo "sk-$(openssl rand -hex 32)"
```

  It is used in the `Authorization` header for every API call:

```bash
Authorization: Bearer sk-xxxxxxxx...
```

  Any client (app, n8n, curl, etc.) must include it to use LiteLLM.

- `host.docker.internal` resolves to the host IP via `extra_hosts`, required for LiteLLM to reach Ollama running on the host.
- The `litellm-database` image includes Postgres support for virtual keys and cost tracking. Use `litellm:main-stable` if you don't need a database.
- The admin dashboard is available at `https://litellm.yourdomain.com/ui`.
- Any OpenAI-compatible client can point to LiteLLM by changing only the `base_url` and `api_key`.