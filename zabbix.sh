cat << 'EOF' > /usr/lib/zabbix/externalscripts/ddn_query.sh
#!/bin/bash

# --- CONFIGURATION ---
IP="10.0.5.43"
BASE_URL="https://$IP"
COOKIE_FILE="/tmp/ddn_zabbix_cookie.txt"

# --- CREDENTIALS ---
API_USER="apiuser"
# Corrected Password (Letter 'O', not Zero)
ENC_PASS="Uw7OX+fWIsAHM2W01LzcDQ=="
SIGN_METHOD="local"

# 1. AUTO-DETECT THE HOSTNAME (CN)
# We fetch the certificate from the server and extract the Common Name (CN)
REAL_HOST=$(echo | openssl s_client -connect $IP:443 2>/dev/null | openssl x509 -noout -subject | sed -n 's/^.*CN *= *\([^/]*\).*$/\1/p')

# Fallback: If auto-detect fails, try 'localhost' (Most common default)
if [ -z "$REAL_HOST" ]; then
    REAL_HOST="localhost"
fi

# 2. ATTEMPT LOGIN
# We use -H "Host: ..." to trick the server into thinking we used the correct name
login_response=$(curl -k -s -c "$COOKIE_FILE" \
     -H "Host: $REAL_HOST" \
     -X POST "$BASE_URL/rest/session" \
     -H 'Content-Type: application/json' \
     -d "{\"userName\":\"$API_USER\",\"password\":\"$ENC_PASS\",\"signInMethod\":\"$SIGN_METHOD\"}")

# 3. ERROR CHECKING
if [[ "$login_response" != *"session_id"* ]]; then
    echo "CRITICAL ERROR: Login Failed."
    echo "Detected Hostname: $REAL_HOST"
    echo "Server Response: $login_response"
    exit 1
fi

# 4. SELECT PAYLOAD
METRIC_TYPE=$1
if [ "$METRIC_TYPE" == "memory" ]; then
    PAYLOAD='{"query":"label_join(node_memory_MemTotal_bytes{hostname=\"ddninsight01\"}, \"node_memory_MemTotal_bytes\", \"\", \"__name__\") or label_join((node_memory_MemTotal_bytes{hostname=\"ddninsight01\"} - node_memory_MemAvailable_bytes{hostname=\"ddninsight01\"}), \"memory_usage\", \"\", \"__name__\")"}'
else
    echo "Error: Unknown metric type"
    exit 1
fi

# 5. FETCH DATA
curl -k -s -b "$COOKIE_FILE" \
     -H "Host: $REAL_HOST" \
     -X POST "$BASE_URL/rest/prometheus/query" \
     -H 'Content-Type: application/json' \
     -d "$PAYLOAD"
EOF
