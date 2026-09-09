package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	healthHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperava status %d, recebeu %d", http.StatusOK, rec.Code)
	}

	body := rec.Body.String()
	if body != "OK\n" {
		t.Errorf("esperava corpo %q, recebeu %q", "OK\n", body)
	}
}
