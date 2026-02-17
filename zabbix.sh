#!/bin/bash

# --- CONFIGURATION ---
# IP of your DDN Insight
BASE_URL="https://10.0.5.43"

# Credentials 
API_USER="apiuser"
ENC_PASS="-Uw7OX+fWIsAHM2W01LzcDQ=="
SIGN_METHOD="-local"

# File to store the temporary cookie
COOKIE_FILE="/tmp/ddn_zabbix_cookie.txt"

# 1. LOGIN (Get a fresh cookie)
# We use -k (insecure) to skip certificate checks for simplicity
login_response=$(curl -k -s -c "$COOKIE_FILE" \
     -X POST "$BASE_URL/rest/session" \
     -H 'Content-Type: application/json' \
     -d "{\"userName\":\"$API_USER\",\"password\":\"$ENC_PASS\",\"signInMethod\":\"$SIGN_METHOD\"}")

# Check if login worked (Look for 'success' or 'session_id')
if [[ "$login_response" != *"session_id"* ]]; then
    echo "Error: Login Failed"
    exit 1
fi

# 2. RUN QUERY (Based on Zabbix Input)
# The first argument sent from Zabbix (e.g., "memory", "cpu")
METRIC_TYPE=$1

if [ "$METRIC_TYPE" == "memory" ]; then
    # The exact payload for Memory Total/Used
    PAYLOAD='{"query":"label_join(node_memory_MemTotal_bytes{hostname=\"ddninsight01\"}, \"node_memory_MemTotal_bytes\", \"\", \"__name__\") or label_join((node_memory_MemTotal_bytes{hostname=\"ddninsight01\"} - node_memory_MemAvailable_bytes{hostname=\"ddninsight01\"}), \"memory_usage\", \"\", \"__name__\")"}'

elif [ "$METRIC_TYPE" == "cpu" ]; then
    # Example CPU payload (You can add more 'elif' blocks for other metrics)
    PAYLOAD='{"query":"irate(node_cpu_seconds_total{mode=\"idle\"}[5m])"}'

else
    echo "Error: Unknown metric type"
    exit 1
fi

# 3. FETCH DATA
curl -k -s -b "$COOKIE_FILE" \
     -X POST "$BASE_URL/rest/prometheus/query" \
     -H 'Content-Type: application/json' \
     -d "$PAYLOAD"
