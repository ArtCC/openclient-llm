# Running Ollama with Docker

This guide shows how to self-host [Ollama](https://ollama.com) using Docker Compose so you can use it as a backend with OpenClient LLM. It covers both CPU-only and NVIDIA GPU setups, along with a reference `.env` file and common operational commands.

## Reference

- https://ollama.com/search

## docker-compose.yml

CPU:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ${OLLAMA_DATA}:/root/.ollama
    environment:
      - OLLAMA_HOST=${OLLAMA_HOST}
      - OLLAMA_MODELS=${OLLAMA_MODELS}
      - OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE}
      - OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}
      - OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}
      - OLLAMA_MAX_QUEUE=${OLLAMA_MAX_QUEUE}
      - OLLAMA_FLASH_ATTENTION=${OLLAMA_FLASH_ATTENTION}
    restart: unless-stopped
```

GPU (NVIDIA):

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ${OLLAMA_DATA}:/root/.ollama
    environment:
      - OLLAMA_HOST=${OLLAMA_HOST}
      - OLLAMA_MODELS=${OLLAMA_MODELS}
      - OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE}
      - OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS}
      - OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}
      - OLLAMA_MAX_QUEUE=${OLLAMA_MAX_QUEUE}
      - OLLAMA_FLASH_ATTENTION=${OLLAMA_FLASH_ATTENTION}
      - NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}
      - NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

## Reference .env

```env
OLLAMA_DATA=/opt/docker/ollama
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=/root/.ollama/models
OLLAMA_KEEP_ALIVE=24h
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_QUEUE=32
OLLAMA_FLASH_ATTENTION=1
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,utility
```

## Operational notes

Prepare the data directory:

```bash
sudo mkdir -p /opt/docker/ollama
sudo chown -R 1000:1000 /opt/docker/ollama
sudo chmod -R 755 /opt/docker/ollama
```

Useful commands:

```bash
docker exec -it ollama ollama list
docker exec -it ollama ollama run MODEL
docker exec -it ollama ollama rm MODEL
```