#!/bin/bash
mkdir -p /tmp/postgres_certs
if [ -d "/opt/hb/confidential_config/postgres_certs" ] && [ "$(ls -A /opt/hb/confidential_config/postgres_certs 2>/dev/null)" ]; then
    cp /opt/hb/confidential_config/postgres_certs/* /tmp/postgres_certs/ 2>/dev/null || true
else
    echo "PostgreSQL certificates not found or SSL disabled - skipping cert copy"
fi
if [ ! -d "/logs" ]; then
    echo "Warning: /logs directory not found"
fi
