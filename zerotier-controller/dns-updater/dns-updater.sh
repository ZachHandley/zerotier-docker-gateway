#!/bin/sh

while true; do
  echo "Fetching ZeroTier members..."

  RESPONSE=$(curl -s -H "x-ztnet-auth: $ZEROTIER_API_KEY" "$ZTNET_URL/api/v1/network/$NETWORK_ID/member/")

  if echo "$RESPONSE" | jq empty 2>/dev/null; then
    echo "Valid JSON received, processing..."

    echo "$RESPONSE" | \
    jq -r '.[] | select(.authorized==true) | select(.ipAssignments != null and (.ipAssignments | length) > 0) | .name + " IN A " + .ipAssignments[0]' | \
    awk '{print tolower($1) " " $2 " " $3 " " $4}' > /data/hosts.tmp

    # Generate zone file
    cat > /data/zmesh.db << EOF
\$TTL 60
\$ORIGIN zmesh.
@   IN SOA ns.zmesh. admin.zmesh. (
        $(date +%Y%m%d%H)
        3600
        1800
        604800
        60 )
    IN NS ns.zmesh.

EOF

    cat /data/hosts.tmp >> /data/zmesh.db
    echo "DNS records updated successfully at $(date)"
  else
    echo "ERROR: Invalid JSON response from API"
  fi

  sleep 60
done
