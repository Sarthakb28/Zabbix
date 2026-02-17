# --- CONFIGURATION ---
IP="10.0.5.43"
COOKIE_FILE="/tmp/ddn_zabbix_cookie.txt"

# --- CREDENTIALS ---
API_USER="apiuser"
ENC_PASS="Uw7OX+fWIsAHM2W01LzcDQ=="
SIGN_METHOD="local"

# 1. GET HOSTNAME (CN)
REAL_HOST=$(echo | openssl s_client -connect $IP:443 2>/dev/null | openssl x509 -noout -subject | sed -n 's/^.*CN *= *\([^/]*\).*$/\1/p')

# Safety fallback if detection fails
if [ -z "$REAL_HOST" ]; then
    REAL_HOST="ddninsight01"
fi

# 2. LOGIN (Using --resolve)
login_response=$(curl -k -s -c "$COOKIE_FILE" \
     --resolve "$REAL_HOST:443:$IP" \
     -X POST "https://$REAL_HOST/rest/session" \
     -H 'Content-Type: application/json' \
     -d "{\"userName\":\"$API_USER\",\"password\":\"$ENC_PASS\",\"signInMethod\":\"$SIGN_METHOD\"}")

# 3. CHECK FOR ERRORS
if [[ "$login_response" != *"session_id"* ]]; then
    echo "CRITICAL ERROR: Login Failed."
    echo "Hostname used: $REAL_HOST"
    echo "Server Response: $login_response"
    exit 1
fi

# 4. QUERY DATA
METRIC_TYPE=$1
if [ "$METRIC_TYPE" == "memory" ]; then
    PAYLOAD='{"query":"label_join(node_memory_MemTotal_bytes{hostname=\"ddninsight01\"}, \"node_memory_MemTotal_bytes\", \"\", \"__name__\") or label_join((node_memory_MemTotal_bytes{hostname=\"ddninsight01\"} - node_memory_MemAvailable_bytes{hostname=\"ddninsight01\"}), \"memory_usage\", \"\", \"__name__\")"}'
else
    echo "Error: Unknown metric type"
    exit 1
fi

# 5. FETCH RESULT
curl -k -s -b "$COOKIE_FILE" \
     --resolve "$REAL_HOST:443:$IP" \
     -X POST "https://$REAL_HOST/rest/prometheus/query" \
     -H 'Content-Type: application/json' \
     -d "$PAYLOAD"
EOF
