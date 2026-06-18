#!/bin/bash
# Admin API Testing Script
# Usage: ./test_admin_api.sh <token>

BASE_URL="http://localhost:8000"

echo "🧪 Testing Admin API Endpoints"
echo "================================"

# Test 1: Public Stats (No Auth)
echo -e "\n1️⃣ Testing Public Stats (No Auth)..."
curl -s "$BASE_URL/api/stats/public/" | python -m json.tool

# Test 2: Login to get token
echo -e "\n2️⃣ Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"admin123"}')

echo "$LOGIN_RESPONSE" | python -m json.tool

TOKEN=$(echo "$LOGIN_RESPONSE" | python -c "import sys, json; print(json.load(sys.stdin)['access'])")
echo -e "\n✅ Got Token: ${TOKEN:0:20}..."

# Test 3: Dashboard Stats (Auth Required)
echo -e "\n3️⃣ Testing Dashboard Stats..."
curl -s "$BASE_URL/api/admin/stats/overview/" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool

# Test 4: List Users
echo -e "\n4️⃣ Testing List Users..."
curl -s "$BASE_URL/api/admin/users/?page=1&page_size=5" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool

# Test 5: Analytics
echo -e "\n5️⃣ Testing Analytics..."
curl -s "$BASE_URL/api/admin/stats/analytics/?start_date=2024-01-01&end_date=2024-12-31" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool

echo -e "\n✅ API Tests Complete!"
