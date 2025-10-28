FROM postgres:16

ARG INSTALL_PGTAP=false

RUN if [ "$INSTALL_PGTAP" = "true" ]; then \
        apt-get update && \
        apt-get install -y postgresql-16-pgtap && \
        rm -rf /var/lib/apt/lists/*; \
    fi
