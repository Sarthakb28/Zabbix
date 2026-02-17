cat << 'EOF' > /usr/lib/zabbix/externalscripts/ddn_query.sh
#!/bin/bash

# --- CONFIGURATION ---
BASE_URL="https://10.0.5.43"
COOKIE_FILE="/tmp/ddn_zabbix_cookie.txt"

API_USER="apiuser"
ENC_PASS="Uw7OX+fWIsAHM2W01LzcDQ=="
SIGN_METHOD="local"

# 1. ATTEMPT LOGIN
# We capture the full response to see errors
login_response=$(curl -k -s -c "$COOKIE_FILE" \
     -X POST "$BASE_URL/rest/session" \
     -H 'Content-Type: application/json' \
     -d "{\"userName\":\"$API_USER\",\"password\":\"$ENC_PASS\",\"signInMethod\":\"$SIGN_METHOD\"}")

# 2. CHECK FOR FAILURE
# If the server reply does NOT contain a session_id, we print the error and stop.
if [[ "$login_response" != *"session_id"* ]]; then
    echo "CRITICAL ERROR: Login Failed."
    echo "Server sent this message: $login_response"
    exit 1
fi

# 3. SELECT PAYLOAD
METRIC_TYPE=$1
if [ "$METRIC_TYPE" == "memory" ]; then
    PAYLOAD='{"query":"label_join(node_memory_MemTotal_bytes{hostname=\"ddninsight01\"}, \"node_memory_MemTotal_bytes\", \"\", \"__name__\") or label_join((node_memory_MemTotal_bytes{hostname=\"ddninsight01\"} - node_memory_MemAvailable_bytes{hostname=\"ddninsight01\"}), \"memory_usage\", \"\", \"__name__\")"}'
else
    echo "Error: Unknown metric type"
    exit 1
fi

# 4. FETCH DATA
curl -k -s -b "$COOKIE_FILE" \
     -X POST "$BASE_URL/rest/prometheus/query" \
     -H 'Content-Type: application/json' \
     -d "$PAYLOAD"
EOF
