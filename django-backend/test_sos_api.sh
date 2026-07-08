#!/bin/bash
# Test script for SOS API endpoints
# Usage: ./test_sos_api.sh BASE_URL ACCESS_TOKEN

BASE_URL=${1:-http://localhost:8000/api}
TOKEN=${2:-"YOUR_TOKEN_HERE"}

echo "=========================================="
echo "SOS API Testing Script"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "Token: ${TOKEN:0:20}..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Store IDs for subsequent tests
SOS_ID=""
RESPONSE_ID=""

# Test 1: Create SOS Request
echo -e "${BLUE}Test 1: Create SOS Request${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/sos/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "blood_type": "O+",
    "patient_name": "Test Patient",
    "age": 30,
    "gender": "male",
    "hospital_name": "Test Hospital",
    "hospital_lat": 40.7128,
    "hospital_lng": -74.0060,
    "units_needed": 2,
    "urgency": "critical"
  }')

echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"

SOS_ID=$(echo "$RESPONSE" | python -c "import sys, json; print(json.load(sys.stdin)['data']['sos']['id'])" 2>/dev/null)

if [ -n "$SOS_ID" ]; then
    echo -e "${GREEN}✅ SOS created with ID: $SOS_ID${NC}"
else
    echo -e "${RED}❌ Failed to create SOS${NC}"
    exit 1
fi

echo ""
sleep 1

# Test 2: List Active SOS
echo -e "${BLUE}Test 2: List Active SOS Requests${NC}"
curl -s -X GET "$BASE_URL/sos/active/" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
echo ""

# Test 3: Respond to SOS (as donor)
echo -e "${BLUE}Test 3: Respond to SOS${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/sos/$SOS_ID/respond/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "can_help": true,
    "estimated_arrival_minutes": 30,
    "note": "On my way!"
  }')

echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"

RESPONSE_ID=$(echo "$RESPONSE" | python -c "import sys, json; print(json.load(sys.stdin)['data']['response']['id'])" 2>/dev/null)

if [ -n "$RESPONSE_ID" ]; then
    echo -e "${GREEN}✅ Response created with ID: $RESPONSE_ID${NC}"
else
    echo -e "${RED}❌ Failed to create response${NC}"
fi

echo ""
sleep 1

# Test 4: Update ETA
if [ -n "$RESPONSE_ID" ]; then
    echo -e "${BLUE}Test 4: Update ETA${NC}"
    curl -s -X POST "$BASE_URL/sos/$SOS_ID/update-eta/$RESPONSE_ID/" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "estimated_arrival_minutes": 15,
        "note": "Running a bit late"
      }' | python -m json.tool
    echo ""
    sleep 1
fi

# Test 5: Confirm Arrival
if [ -n "$RESPONSE_ID" ]; then
    echo -e "${BLUE}Test 5: Confirm Arrival${NC}"
    curl -s -X POST "$BASE_URL/sos/$SOS_ID/confirm-arrival/$RESPONSE_ID/" \
      -H "Authorization: Bearer $TOKEN" | python -m json.tool
    echo ""
    sleep 1
fi

# Test 6: Confirm Arrival
if [ -n "$RESPONSE_ID" ]; then
    echo -e "${BLUE}Test 6: Confirm Arrival${NC}"
    curl -s -X POST "$BASE_URL/sos/$SOS_ID/confirm-arrival/$RESPONSE_ID/" \
      -H "Authorization: Bearer $TOKEN" | python -m json.tool
    echo ""
    sleep 1
fi

# Test 7: Get SOS Detail
echo -e "${BLUE}Test 7: Get SOS Detail${NC}"
curl -s -X GET "$BASE_URL/sos/$SOS_ID/" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
echo ""

# Test 8: Create another response to test rejection
echo -e "${BLUE}Test 8: Create Second Response (for rejection test)${NC}"
RESPONSE2=$(curl -s -X POST "$BASE_URL/sos/$SOS_ID/respond/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "can_help": true,
    "estimated_arrival_minutes": 45,
    "note": "I can also help"
  }')

echo "$RESPONSE2" | python -m json.tool 2>/dev/null || echo "$RESPONSE2"
RESPONSE2_ID=$(echo "$RESPONSE2" | python -c "import sys, json; data=json.load(sys.stdin); print(data.get('data', {}).get('response', {}).get('id', ''))" 2>/dev/null)

if [ -n "$RESPONSE2_ID" ]; then
    echo -e "${GREEN}✅ Second response created: $RESPONSE2_ID${NC}"
    sleep 1

    # Test 9: Reject Response
    echo -e "${BLUE}Test 9: Reject Response${NC}"
    curl -s -X POST "$BASE_URL/sos/$SOS_ID/reject-response/$RESPONSE2_ID/" \
      -H "Authorization: Bearer $TOKEN" | python -m json.tool
    echo ""
fi

# Test 10: Cancel SOS
echo -e "${BLUE}Test 10: Cancel SOS${NC}"
curl -s -X POST "$BASE_URL/sos/$SOS_ID/cancel/" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
echo ""

echo -e "${GREEN}=========================================="
echo "✅ API Testing Complete!"
echo "==========================================${NC}"
echo ""
echo "📝 Summary:"
echo "  • SOS ID: $SOS_ID"
echo "  • Response 1 ID: $RESPONSE_ID"
echo "  • Response 2 ID: ${RESPONSE2_ID:-N/A}"
