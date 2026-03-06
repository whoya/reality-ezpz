package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

type app struct {
	token          string
	composeProject string
	composeDir     string
	usernameRegex  *regexp.Regexp
	uuidRegex      *regexp.Regexp
}

func main() {
	a := &app{
		token:          os.Getenv("HELPER_TOKEN"),
		composeProject: getEnv("COMPOSE_PROJECT", "reality-ezpz"),
		composeDir:     getEnv("COMPOSE_DIR", "/opt/reality-ezpz"),
		usernameRegex:  regexp.MustCompile(`^[a-zA-Z0-9]+$`),
		uuidRegex:      regexp.MustCompile(`^[a-fA-F0-9-]{36}$`),
	}
	if a.token == "" {
		log.Fatal("HELPER_TOKEN is required")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", a.handleHealth)
	mux.HandleFunc("/v1/engine/restart", a.withAuth(a.handleEngineRestart))
	mux.HandleFunc("/v1/engine/users/add", a.withAuth(a.handleEngineUserAdd))
	mux.HandleFunc("/v1/engine/users/remove", a.withAuth(a.handleEngineUserRemove))
	mux.HandleFunc("/v1/engine/experimental/vlessenc", a.withAuth(a.handleVLESSEnc))

	server := &http.Server{
		Addr:              getEnv("HELPER_LISTEN", ":8090"),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("vpn-helper listening on %s", server.Addr)
	log.Fatal(server.ListenAndServe())
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func (a *app) withAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := strings.TrimSpace(r.Header.Get("Authorization"))
		if auth != "Bearer "+a.token {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func (a *app) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *app) handleEngineRestart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := a.restartEngine(); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "restarted",
		"service": "engine",
	})
}

func (a *app) restartEngine() error {
	cmd := exec.Command("docker", a.composeBaseArgs("restart", "--timeout", "2", "engine")...)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return nil
	}
	fallback := exec.Command("docker", a.composeBaseArgs("up", "-d", "--no-deps", "engine")...)
	out2, err2 := fallback.CombinedOutput()
	if err2 == nil {
		return nil
	}
	return fmt.Errorf(
		"restart failed: %s; fallback failed: %s",
		strings.TrimSpace(string(out)),
		strings.TrimSpace(string(out2)),
	)
}

type userAddRequest struct {
	Tag      string `json:"tag"`
	Email    string `json:"email"`
	UUID     string `json:"uuid"`
	Flow     string `json:"flow,omitempty"`
	TestSeed string `json:"test_seed,omitempty"`
}

type userRemoveRequest struct {
	Tag   string `json:"tag"`
	Email string `json:"email"`
}

func (a *app) handleEngineUserAdd(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req userAddRequest
	if err := decodeJSON(r, &req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if req.Tag == "" {
		req.Tag = "inbound"
	}
	if !a.usernameRegex.MatchString(req.Email) {
		http.Error(w, "invalid email/username", http.StatusBadRequest)
		return
	}
	if !a.uuidRegex.MatchString(req.UUID) {
		http.Error(w, "invalid uuid", http.StatusBadRequest)
		return
	}
	if req.Flow != "" && req.Flow != "xtls-rprx-vision" {
		http.Error(w, "unsupported flow", http.StatusBadRequest)
		return
	}
	if err := a.addUserViaXrayAPI(req); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "added",
		"tag":    req.Tag,
		"email":  req.Email,
	})
}

func (a *app) handleEngineUserRemove(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req userRemoveRequest
	if err := decodeJSON(r, &req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if req.Tag == "" {
		req.Tag = "inbound"
	}
	if !a.usernameRegex.MatchString(req.Email) {
		http.Error(w, "invalid email/username", http.StatusBadRequest)
		return
	}
	if err := a.removeUserViaXrayAPI(req); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "removed",
		"tag":    req.Tag,
		"email":  req.Email,
	})
}

func (a *app) handleVLESSEnc(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	cmd := exec.Command("docker", a.composeBaseArgs("exec", "-T", "engine", "xray", "vlessenc")...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("xray vlessenc failed: %s", strings.TrimSpace(string(out))), http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"output": strings.TrimSpace(string(out)),
	})
}

func (a *app) addUserViaXrayAPI(req userAddRequest) error {
	client := map[string]any{
		"id":    req.UUID,
		"email": req.Email,
	}
	if req.Flow != "" {
		client["flow"] = req.Flow
	}
	if req.TestSeed != "" {
		client["testSeed"] = req.TestSeed
	}
	payload, err := json.Marshal(map[string]any{
		"inbounds": []any{
			map[string]any{
				"tag":      req.Tag,
				"protocol": "vless",
				"settings": map[string]any{
					"decryption": "none",
					"clients":    []any{client},
				},
			},
		},
	})
	if err != nil {
		return err
	}

	script := `tmp="/tmp/xray-adu.$$.json"; cat >"$tmp"; xray api adu --server=127.0.0.1:10085 "$tmp"; rc=$?; rm -f "$tmp"; exit $rc`
	cmd := exec.Command("docker", a.composeBaseArgs("exec", "-T", "engine", "sh", "-lc", script)...)
	cmd.Stdin = bytes.NewReader(payload)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("xray api adu failed: %s", strings.TrimSpace(string(out)))
	}
	return nil
}

func (a *app) removeUserViaXrayAPI(req userRemoveRequest) error {
	args := a.composeBaseArgs("exec", "-T", "engine", "xray", "api", "rmu", "--server=127.0.0.1:10085", "-tag="+req.Tag, req.Email)
	cmd := exec.Command("docker", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("xray api rmu failed: %s", strings.TrimSpace(string(out)))
	}
	return nil
}

func (a *app) composeBaseArgs(extra ...string) []string {
	base := []string{
		"compose",
		"--project-directory", a.composeDir,
		"-p", a.composeProject,
	}
	return append(base, extra...)
}

func decodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(dst)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
