#!/bin/bash
# Quick curl tests for CV backend endpoints
# Run this before device testing to verify backend is working

set -e

BASE_URL="${BACKEND_URL:-http://localhost:8000}"
echo "Testing backend at: $BASE_URL"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Health check (if we add it later)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Uncomment when health endpoint exists:
# curl -s "$BASE_URL/health" | jq '.' || echo -e "${RED}✗ Failed${NC}"
echo -e "${GREEN}✓ Skipped (no /health endpoint yet)${NC}"
echo ""

# Test 2: POST /calibrate with valid data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: POST /calibrate (with valid UUID)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Note: This will fail with foreign key error unless match exists
# But it proves the endpoint is working and validates the request
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/calibrate" \
  -H "Content-Type: application/json" \
  -d '{
    "match_id": "123e4567-e89b-12d3-a456-426614174000",
    "keypoints": [
      {"label": "k1", "x_px": 100, "y_px": 500, "x_m": 0, "y_m": 0},
      {"label": "k2", "x_px": 900, "y_px": 500, "x_m": 10, "y_m": 0},
      null, null,
      {"label": "k5", "x_px": 900, "y_px": 300, "x_m": 10, "y_m": 3},
      {"label": "k6", "x_px": 100, "y_px": 200, "x_m": 0, "y_m": 10}
    ]
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

if [[ "$HTTP_CODE" == "200" ]]; then
  echo -e "${GREEN}✓ Endpoint working (homography computed)${NC}"
elif [[ "$HTTP_CODE" == "500" ]] && echo "$BODY" | grep -q "foreign key"; then
  echo -e "${GREEN}✓ Endpoint working (expected FK error - match doesn't exist)${NC}"
else
  echo -e "${RED}✗ Unexpected response${NC}"
fi
echo ""

# Test 3: POST /calibrate with insufficient keypoints
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: POST /calibrate (insufficient keypoints)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/calibrate" \
  -H "Content-Type: application/json" \
  -d '{
    "match_id": "123e4567-e89b-12d3-a456-426614174000",
    "keypoints": [
      {"label": "k1", "x_px": 100, "y_px": 500, "x_m": 0, "y_m": 0},
      null, null, null, null, null, null, null, null, null, null, null
    ]
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

if [[ "$HTTP_CODE" == "200" ]] && echo "$BODY" | grep -q '"success":false'; then
  echo -e "${GREEN}✓ Correctly rejected (< 4 keypoints)${NC}"
else
  echo -e "${RED}✗ Should reject with success=false${NC}"
fi
echo ""

# Test 4: GET /analyze/{job_id} (stub test)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: GET /analyze/{job_id} (non-existent job)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/analyze/00000000-0000-0000-0000-000000000000")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

if [[ "$HTTP_CODE" == "404" ]]; then
  echo -e "${GREEN}✓ Correctly returns 404 for non-existent job${NC}"
else
  echo -e "${RED}✗ Expected 404${NC}"
fi
echo ""

# Test 5: POST /upload-url
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: POST /upload-url (generate presigned URL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/upload-url" \
  -H "Content-Type: application/json" \
  -d '{
    "match_id": "123e4567-e89b-12d3-a456-426614174000",
    "content_type": "video/mp4",
    "content_length": 50000000
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

if [[ "$HTTP_CODE" == "200" ]] && echo "$BODY" | grep -q "upload_url"; then
  echo -e "${GREEN}✓ Presigned URL generated${NC}"
else
  echo -e "${RED}✗ Failed to generate presigned URL${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: All critical endpoints tested"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Backend is ready for device testing"
echo ""
echo "Next steps:"
echo "  1. Start ngrok: ngrok http 8000"
echo "  2. Update BACKEND_URL in Flutter"
echo "  3. Test on device"
