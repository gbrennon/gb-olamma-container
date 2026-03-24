FROM ollama/ollama:latest

USER root
RUN apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY scripts/load-models.sh /usr/local/bin/load-models.sh
RUN chmod +x /usr/local/bin/load-models.sh

EXPOSE 11434

ENTRYPOINT ["/usr/local/bin/load-models.sh"]
