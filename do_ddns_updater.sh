#!/bin/sh

# Script to update a DigitalOcean DNS A record with the current public IP.
# Can run once or repeatedly at a specified interval.

# Prerequisites:
# - curl: For making HTTP requests.
# - jq: For parsing JSON responses from the DigitalOcean API.

# Required Environment Variables:
# - DO_TOKEN: Your DigitalOcean API token with read and write access.
# - DOMAIN: The base domain name (e.g., example.com).
# - NAME: The subdomain part of the DNS record (e.g., home, www). Use "@" for the root domain.

# Optional Environment Variables:
# - IP_SERVICE: URL of the service to fetch the public IP from (defaults to ifconfig.co).
# - UPDATE_INTERVAL: Interval in seconds to re-run the script. If not set or <= 0, runs once.

# --- Check for dependencies ---
if ! command -v jq > /dev/null; then
    echo "Error: jq is not installed. Please install jq to run this script."
    exit 1
fi
if ! command -v curl > /dev/null; then
    echo "Error: curl is not installed. Please install curl to run this script."
    exit 1
fi

# --- Function to perform the DNS update ---
update_dns() {
    # Ensure required variables are set
    if [ -z "${DO_TOKEN}" ]; then
        echo "Error: Required variable \$DO_TOKEN is empty! see: https://docs.digitalocean.com/reference/api/create-personal-access-token/"
        exit 2 # Exit script because this is a fatal configuration error
    fi

    if [ -z "${DOMAIN}" ]; then
        echo "Error: Required variable \$DOMAIN is empty!"
	echo "This is your domain within the DigitalOcean control panel"
        exit 2 # Exit script
    fi

    if [ -z "${NAME}" ]; then
        echo "Error: Required variable \$NAME is empty!"
	echo "This is your subdomain record to update"
        exit 2 # Exit script
    fi

    # Fetch public IP
    echo "Fetching public IP from ${IP_SERVICE:-ifconfig.co}..."
    IP=$(curl -s "${IP_SERVICE:-ifconfig.co}" | grep -Eo '[0-9\.]+')

    # IP is not available
    if [ -z "${IP}" ]; then
        echo "Error: Could not retrieve public IP from \"${IP_SERVICE:-ifconfig.co}\"."
        return 3 # Return error code to calling loop/block
    fi
    echo "Current Public IP: ${IP}"

    # Fetch existing DNS records for the domain
    echo "Fetching DNS records for ${DOMAIN}..."
    RECORDS_JSON=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${DO_TOKEN}" \
        "https://api.digitalocean.com/v2/domains/${DOMAIN}/records")

    # Check if curl failed or returned empty/invalid JSON
    if [ -z "${RECORDS_JSON}" ] || ! echo "${RECORDS_JSON}" | jq empty 2>/dev/null; then
        echo "Error: Failed to fetch records or received invalid JSON from DigitalOcean API for domain ${DOMAIN}."
        echo "Response: ${RECORDS_JSON}"
        return 3
    fi

    # Extract the ID and current data of the specific A record
    # Using jq -r for raw string output (no quotes)
    # Targetting A record with the specific NAME
    RECORD_INFO=$(echo "${RECORDS_JSON}" | jq -r ".domain_records[] | select(.type == \"A\" and .name == \"${NAME}\") | {id: .id, data: .data} | @json")

    if [ -z "${RECORD_INFO}" ] || [ "${RECORD_INFO}" = "null" ]; then
        echo "Error: Could not find an A record with name \"${NAME}\" for domain \"${DOMAIN}\"."
        echo "Please ensure the A record exists in your DigitalOcean DNS settings."
        # For debugging, you might want to see all records:
        # echo "Available records for ${DOMAIN}:"
        # echo "${RECORDS_JSON}" | jq '.domain_records[] | {name: .name, type: .type, id: .id, data: .data}'
        return 3
    fi

    RECORD_ID=$(echo "${RECORD_INFO}" | jq -r '.id')
    CURRENT_DNS_IP=$(echo "${RECORD_INFO}" | jq -r '.data')

    if [ -z "${RECORD_ID}" ] || [ "${RECORD_ID}" = "null" ]; then # Should be caught by RECORD_INFO check, but good to be safe
        echo "Error: Could not retrieve DNS record ID for A record \"${NAME}.${DOMAIN}\"."
        return 3
    fi
    echo "Found Record ID: ${RECORD_ID} for ${NAME}.${DOMAIN}. Current DNS IP: ${CURRENT_DNS_IP}"

    # Compare current public IP with DNS IP
    if [ "${IP}" = "${CURRENT_DNS_IP}" ]; then
        echo "IP address (${IP}) has not changed. No update needed for ${NAME}.${DOMAIN}."
        return 0 # Success, no update needed
    fi

    # IP has changed, proceed with update
    echo "IP address has changed to ${IP}. Updating DNS record ${NAME}.${DOMAIN} (ID: ${RECORD_ID})..."
    UPDATE_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${DO_TOKEN}" \
        -d "{\"type\": \"A\", \"name\": \"${NAME}\", \"data\": \"${IP}\"}" \
        "https://api.digitalocean.com/v2/domains/${DOMAIN}/records/${RECORD_ID}")

    if [ "${UPDATE_RESPONSE_CODE}" -ge 200 ] && [ "${UPDATE_RESPONSE_CODE}" -lt 300 ]; then
        echo "Successfully updated ${NAME}.${DOMAIN} to ${IP}. HTTP Status: ${UPDATE_RESPONSE_CODE}"
    else
        echo "Error: Failed to update DNS record for ${NAME}.${DOMAIN}."
        echo "API URL: https://api.digitalocean.com/v2/domains/${DOMAIN}/records/${RECORD_ID}"
        echo "Payload: {\"type\": \"A\", \"name\": \"${NAME}\", \"data\": \"${IP}\"}"
        echo "HTTP Status: ${UPDATE_RESPONSE_CODE}"
        # To get the full response body on error, you'd remove -o /dev/null and capture stdout
        # For example: FULL_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" ... )
        return 4 # Return error code for update failure
    fi

    return 0 # Success
}

# --- Main script execution ---

# Check for UPDATE_INTERVAL to decide on looping
# The `2>/dev/null` suppresses "integer expression expected" error if UPDATE_INTERVAL is not a number.
if [ -n "${UPDATE_INTERVAL}" ] && [ "${UPDATE_INTERVAL}" -gt 0 ] 2>/dev/null; then
    echo "Script will run every ${UPDATE_INTERVAL} seconds. Press [CTRL+C] to stop."
    while true; do
        echo "" # Newline for readability
        echo "--- Starting DNS update cycle at $(date) ---"
        update_dns
        status=$? # Store exit status of update_dns
        if [ $status -ne 0 ] && [ $status -ne 2 ]; then # Don't log retry if it was a fatal config error (exit 2)
            echo "DNS update function reported an issue (status $status). Will retry after interval."
        elif [ $status -eq 2 ]; then
             echo "DNS update function failed due to missing configuration. Exiting."
             exit $status # Exit the loop and script if config is missing
        fi
        echo "--- Cycle finished. Sleeping for ${UPDATE_INTERVAL} seconds... ---"
        sleep "${UPDATE_INTERVAL}"
    done
else
    update_dns
    status=$?
    if [ $status -eq 0 ]; then
        echo "DNS update process completed successfully."
    else
        echo "DNS update process failed with status $status."
    fi
    exit $status # Exit with the status from update_dns
fi

# Should not be reached if looping, but good practice for single run.
exit 0



