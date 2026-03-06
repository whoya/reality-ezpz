package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

type app struct {
	configPath    string
	apiToken      string
	helperURL     string
	helperToken   string
	httpClient    *http.Client
	mu            sync.Mutex
	usernameRegex *regexp.Regexp
}

type usersResponse struct {
	Users []string `json:"users"`
}

type userRequest struct {
	Username string `json:"username"`
}

type configResponse struct {
	Username string   `json:"username"`
	Configs  []string `json:"configs"`
}

type errorResponse struct {
	Error string `json:"error"`
}

type vlessEncResponse struct {
	Status string `json:"status"`
	Output string `json:"output"`
}

type subEntry struct {
	Token     string `json:"token"`
	CreatedAt string `json:"created_at"`
	RotatedAt string `json:"rotated_at"`
}

type subsFile struct {
	Version int                `json:"version"`
	Users   map[string]subEntry `json:"users"`
}

type subscriptionResponse struct {
	Username string `json:"username"`
	URL      string `json:"url"`
	Path     string `json:"path"`
	Enabled  bool   `json:"enabled"`
}

type rotateResponse struct {
	Username string `json:"username"`
	URL      string `json:"url"`
	Path     string `json:"path"`
	Rotated  bool   `json:"rotated"`
}

func main() {
	a := &app{
		configPath:    getEnv("CONFIG_PATH", "/opt/reality-ezpz"),
		apiToken:      os.Getenv("API_TOKEN"),
		helperURL:     strings.TrimRight(getEnv("HELPER_URL", "http://vpn-helper:8090"), "/"),
		helperToken:   os.Getenv("HELPER_TOKEN"),
		httpClient:    &http.Client{Timeout: 10 * time.Second},
		usernameRegex: regexp.MustCompile(`^[a-zA-Z0-9]+$`),
	}

	if a.apiToken == "" {
		log.Fatal("API_TOKEN is required")
	}
	if a.helperToken == "" {
		log.Fatal("HELPER_TOKEN is required")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", a.handleHealth)
	mux.HandleFunc("/v1/users", a.withAuth(a.handleUsers))
	mux.HandleFunc("/v1/users/", a.withAuth(a.handleUserRoutes))
	mux.HandleFunc("/v1/server-config", a.withAuth(a.handleServerConfig))
	mux.HandleFunc("/v1/experimental/vlessenc", a.withAuth(a.handleExperimentalVLESSEnc))

	listenAddr := getEnv("API_LISTEN", ":8080")
	server := &http.Server{
		Addr:              listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("vpn-api listening on %s", listenAddr)
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
		if auth != "Bearer "+a.apiToken {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next(w, r)
	}
}

// ipv6Cache holds the last resolved IPv6 address with a 1-hour TTL.
var ipv6Cache struct {
	mu        sync.Mutex
	address   string
	fetchedAt time.Time
}

// cachedIPv6 returns the server's IPv6 address, refreshing at most once per hour.
func cachedIPv6() string {
	ipv6Cache.mu.Lock()
	defer ipv6Cache.mu.Unlock()
	if time.Since(ipv6Cache.fetchedAt) < time.Hour {
		return ipv6Cache.address
	}
	ipv6Cache.address = fetchIPv6()
	ipv6Cache.fetchedAt = time.Now()
	return ipv6Cache.address
}

func (a *app) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *app) handleUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		users, err := a.loadUsers()
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, usersResponse{Users: sortedKeys(users)})
	case http.MethodPost:
		var req userRequest
		if err := decodeJSON(r.Body, &req); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		if !a.usernameRegex.MatchString(req.Username) {
			writeError(w, http.StatusBadRequest, "invalid username")
			return
		}
		if err := a.addUser(req.Username); err != nil {
			code := http.StatusInternalServerError
			if errors.Is(err, errConflict) {
				code = http.StatusConflict
			}
			writeError(w, code, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, map[string]string{"status": "created", "username": req.Username})
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (a *app) handleUserRoutes(w http.ResponseWriter, r *http.Request) {
	trimmed := strings.TrimPrefix(r.URL.Path, "/v1/users/")
	if trimmed == "" || trimmed == r.URL.Path {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	parts := strings.Split(trimmed, "/")
	username := parts[0]
	if !a.usernameRegex.MatchString(username) {
		writeError(w, http.StatusBadRequest, "invalid username")
		return
	}

	if len(parts) == 2 && parts[1] == "config" {
		if r.Method != http.MethodGet {
			writeError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		cfg, users, err := a.loadState()
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		uuid, exists := users[username]
		if !exists {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		configs := buildVLESSConfigs(username, uuid, cfg)
		writeJSON(w, http.StatusOK, configResponse{Username: username, Configs: configs})
		return
	}

	if len(parts) == 2 && parts[1] == "subscription" {
		a.handleSubscription(w, r, username)
		return
	}

	if len(parts) == 3 && parts[1] == "subscription" && parts[2] == "rotate" {
		a.handleRotateSubscription(w, r, username)
		return
	}

	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "not found")
		return
	}

	switch r.Method {
	case http.MethodGet:
		users, err := a.loadUsers()
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		uuid, exists := users[username]
		if !exists {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"username": username, "uuid": uuid})
	case http.MethodDelete:
		if err := a.deleteUser(username); err != nil {
			code := http.StatusInternalServerError
			if errors.Is(err, errNotFound) {
				code = http.StatusNotFound
			}
			if errors.Is(err, errValidation) {
				code = http.StatusBadRequest
			}
			writeError(w, code, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "deleted", "username": username})
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (a *app) handleServerConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	cfg, err := loadKVFile(a.configFile())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	resp := map[string]string{
		"core":              "xray",
		"server":            cfg["server"],
		"domain":            cfg["domain"],
		"port":              cfg["port"],
		"transport":         cfg["transport"],
		"security":          cfg["security"],
		"short_ids":         cfg["short_ids"],
		"xray_version_min":  cfg["xray_version_min"],
		"xray_experimental": cfg["xray_experimental"],
		"experimental_user": cfg["experimental_user"],
		"safenet":           cfg["safenet"],
		"warp":              cfg["warp"],
		"warp_license":      cfg["warp_license"],
		"tgbot":             cfg["tgbot"],
		"tgbot_admin_ids":   cfg["tgbot_admin_ids"],
		"service_path":      cfg["service_path"],
		"public_key":        cfg["public_key"],
		"short_id":          cfg["short_id"],
		"internal_api":      "enabled",
		"internal_auth":     "bearer",
	}
	writeJSON(w, http.StatusOK, resp)
}

func (a *app) handleExperimentalVLESSEnc(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	req, err := http.NewRequest(http.MethodPost, a.helperURL+"/v1/engine/experimental/vlessenc", bytes.NewReader([]byte(`{}`)))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	req.Header.Set("Authorization", "Bearer "+a.helperToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := a.httpClient.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusBadRequest {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		writeError(w, http.StatusBadGateway, strings.TrimSpace(string(data)))
		return
	}
	var payload vlessEncResponse
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64*1024)).Decode(&payload); err != nil {
		writeError(w, http.StatusBadGateway, "invalid helper response")
		return
	}
	writeJSON(w, http.StatusOK, payload)
}

var (
	errConflict   = errors.New("resource already exists")
	errNotFound   = errors.New("resource not found")
	errValidation = errors.New("validation error")
)

type runtimeUserAction struct {
	kind     string
	username string
	uuid     string
	flow     string
	testSeed string
}

func cloneMap(src map[string]string) map[string]string {
	dst := make(map[string]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func (a *app) addUser(username string) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	cfg, users, err := a.loadState()
	if err != nil {
		return err
	}
	if _, exists := users[username]; exists {
		return fmt.Errorf("%w: user already exists", errConflict)
	}
	originalUsers := cloneMap(users)
	originalEngine, err := os.ReadFile(a.engineFile())
	if err != nil {
		return err
	}

	uuid, err := generateUUID()
	if err != nil {
		return err
	}
	users[username] = uuid

	flow := ""
	if cfg["transport"] == "tcp" {
		flow = "xtls-rprx-vision"
	}
	testSeed := ""
	if cfg["xray_experimental"] == "ON" && cfg["experimental_user"] == username {
		testSeed = cfg["experimental_test_seed"]
	}
	if err := a.applyUsersState(cfg, users, originalUsers, originalEngine, runtimeUserAction{
		kind:     "add",
		username: username,
		uuid:     uuid,
		flow:     flow,
		testSeed: testSeed,
	}); err != nil {
		return err
	}
	if cfg["subscriptions"] == "ON" {
		if serr := a.syncSubscriptionsForUser(username); serr != nil {
			log.Printf("warning: failed to sync subscription for %s: %v", username, serr)
		}
	}
	return nil
}

func (a *app) deleteUser(username string) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	cfg, users, err := a.loadState()
	if err != nil {
		return err
	}
	if _, exists := users[username]; !exists {
		return fmt.Errorf("%w: user not found", errNotFound)
	}
	if len(users) == 1 {
		return fmt.Errorf("%w: cannot delete the only user", errValidation)
	}
	originalUsers := cloneMap(users)
	originalEngine, err := os.ReadFile(a.engineFile())
	if err != nil {
		return err
	}
	delete(users, username)

	if err := a.applyUsersState(cfg, users, originalUsers, originalEngine, runtimeUserAction{
		kind:     "remove",
		username: username,
	}); err != nil {
		return err
	}
	if serr := a.removeSubscriptionForUser(username); serr != nil {
		log.Printf("warning: failed to remove subscription for %s: %v", username, serr)
	}
	return nil
}

func (a *app) applyUsersState(cfg map[string]string, users map[string]string, originalUsers map[string]string, originalEngine []byte, action runtimeUserAction) error {
	if err := a.writeUsers(users); err != nil {
		return err
	}
	if err := a.updateEngineClients(cfg, users); err != nil {
		_ = a.writeUsers(originalUsers)
		_ = os.WriteFile(a.engineFile(), originalEngine, 0o600)
		return fmt.Errorf("failed to update engine clients: %w", err)
	}
	if err := a.applyRuntimeUserAction(action); err != nil {
		_ = a.writeUsers(originalUsers)
		_ = os.WriteFile(a.engineFile(), originalEngine, 0o600)
		return fmt.Errorf("failed to apply runtime user change via xray api: %w", err)
	}
	return nil
}

func (a *app) applyRuntimeUserAction(action runtimeUserAction) error {
	var path string
	body := map[string]string{
		"tag":   "inbound",
		"email": action.username,
	}
	switch action.kind {
	case "add":
		path = "/v1/engine/users/add"
		body["uuid"] = action.uuid
		if action.flow != "" {
			body["flow"] = action.flow
		}
		if action.testSeed != "" {
			body["test_seed"] = action.testSeed
		}
	case "remove":
		path = "/v1/engine/users/remove"
	default:
		return fmt.Errorf("unsupported runtime action: %s", action.kind)
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, a.helperURL+path, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+a.helperToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusBadRequest {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		if strings.TrimSpace(string(data)) == "" {
			return fmt.Errorf("helper returned HTTP %d", resp.StatusCode)
		}
		return fmt.Errorf("helper returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(data)))
	}
	return nil
}

func (a *app) updateEngineClients(cfg map[string]string, users map[string]string) error {
	enginePath := a.engineFile()
	raw, err := os.ReadFile(enginePath)
	if err != nil {
		return err
	}
	var root map[string]any
	if err := json.Unmarshal(raw, &root); err != nil {
		return err
	}
	inbounds, ok := root["inbounds"].([]any)
	if !ok {
		return errors.New("invalid engine config: inbounds")
	}

	flow := ""
	if cfg["transport"] == "tcp" {
		flow = "xtls-rprx-vision"
	}
	clients := make([]any, 0, len(users))
	for _, username := range sortedKeys(users) {
		client := map[string]any{
			"id":    users[username],
			"email": username,
		}
		if flow != "" {
			client["flow"] = flow
		}
		if cfg["xray_experimental"] == "ON" &&
			cfg["experimental_user"] == username &&
			cfg["experimental_test_seed"] != "" {
			client["testSeed"] = cfg["experimental_test_seed"]
		}
		clients = append(clients, client)
	}

	updated := false
	for _, item := range inbounds {
		inbound, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if inbound["protocol"] != "vless" {
			continue
		}
		settings, ok := inbound["settings"].(map[string]any)
		if !ok {
			continue
		}
		settings["clients"] = clients
		updated = true
	}
	if !updated {
		return errors.New("vless inbound not found in engine config")
	}

	out, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(enginePath, append(out, '\n'), 0o600)
}

func (a *app) loadState() (map[string]string, map[string]string, error) {
	cfg, err := loadKVFile(a.configFile())
	if err != nil {
		return nil, nil, err
	}
	users, err := a.loadUsers()
	if err != nil {
		return nil, nil, err
	}
	return cfg, users, nil
}

func (a *app) loadUsers() (map[string]string, error) {
	return loadKVFile(a.usersFile())
}

func (a *app) writeUsers(users map[string]string) error {
	var b strings.Builder
	for _, username := range sortedKeys(users) {
		b.WriteString(username)
		b.WriteString("=")
		b.WriteString(users[username])
		b.WriteString("\n")
	}
	return os.WriteFile(a.usersFile(), []byte(b.String()), 0o600)
}

func (a *app) configFile() string {
	return filepath.Join(a.configPath, "config")
}

func (a *app) usersFile() string {
	return filepath.Join(a.configPath, "users")
}

func (a *app) engineFile() string {
	return filepath.Join(a.configPath, "engine.conf")
}

func (a *app) subscriptionsFile() string {
	return filepath.Join(a.configPath, "subscriptions.json")
}

// ── Subscription helpers ──────────────────────────────────────────────────────

func generateToken() (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

func (a *app) loadSubscriptions() (*subsFile, error) {
	data, err := os.ReadFile(a.subscriptionsFile())
	if os.IsNotExist(err) {
		return &subsFile{Version: 1, Users: map[string]subEntry{}}, nil
	}
	if err != nil {
		return nil, err
	}
	var s subsFile
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	if s.Users == nil {
		s.Users = map[string]subEntry{}
	}
	return &s, nil
}

func (a *app) writeSubscriptions(s *subsFile) error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	dir := filepath.Dir(a.subscriptionsFile())
	tmp, err := os.CreateTemp(dir, ".subscriptions-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName) //nolint:errcheck
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Chmod(tmpName, 0o600); err != nil {
		return err
	}
	return os.Rename(tmpName, a.subscriptionsFile())
}

// syncSubscriptionsForUser ensures the user has a token entry. Must be called under a.mu.
func (a *app) syncSubscriptionsForUser(username string) error {
	s, err := a.loadSubscriptions()
	if err != nil {
		return err
	}
	if _, exists := s.Users[username]; exists {
		return nil
	}
	token, err := generateToken()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	s.Users[username] = subEntry{Token: token, CreatedAt: now, RotatedAt: now}
	return a.writeSubscriptions(s)
}

// removeSubscriptionForUser removes the user's token entry. Must be called under a.mu.
func (a *app) removeSubscriptionForUser(username string) error {
	s, err := a.loadSubscriptions()
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if _, exists := s.Users[username]; !exists {
		return nil
	}
	delete(s.Users, username)
	return a.writeSubscriptions(s)
}

func (a *app) subscriptionURL(token string, cfg map[string]string) string {
	subPath := cfg["subscription_path"]
	if subPath == "" {
		subPath = "sub"
	}
	host := cfg["server"]
	port := cfg["port"]
	if port != "" && port != "443" {
		host = host + ":" + port
	}
	return fmt.Sprintf("https://%s/%s/%s", host, subPath, token)
}

func (a *app) handleSubscription(w http.ResponseWriter, r *http.Request, username string) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()

	cfg, users, err := a.loadState()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, exists := users[username]; !exists {
		writeError(w, http.StatusNotFound, "user not found")
		return
	}
	if cfg["subscriptions"] != "ON" {
		writeError(w, http.StatusConflict, "subscriptions feature is disabled")
		return
	}
	s, err := a.loadSubscriptions()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	entry, exists := s.Users[username]
	if !exists {
		writeError(w, http.StatusInternalServerError, "subscription entry not found; run sync")
		return
	}
	subPath := cfg["subscription_path"]
	if subPath == "" {
		subPath = "sub"
	}
	url := a.subscriptionURL(entry.Token, cfg)
	path := "/" + subPath + "/" + entry.Token
	writeJSON(w, http.StatusOK, subscriptionResponse{
		Username: username,
		URL:      url,
		Path:     path,
		Enabled:  true,
	})
}

func (a *app) handleRotateSubscription(w http.ResponseWriter, r *http.Request, username string) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()

	cfg, users, err := a.loadState()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, exists := users[username]; !exists {
		writeError(w, http.StatusNotFound, "user not found")
		return
	}
	if cfg["subscriptions"] != "ON" {
		writeError(w, http.StatusConflict, "subscriptions feature is disabled")
		return
	}
	s, err := a.loadSubscriptions()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	token, err := generateToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	now := time.Now().UTC().Format(time.RFC3339)
	existing := s.Users[username]
	s.Users[username] = subEntry{
		Token:     token,
		CreatedAt: existing.CreatedAt,
		RotatedAt: now,
	}
	if existing.CreatedAt == "" {
		s.Users[username] = subEntry{Token: token, CreatedAt: now, RotatedAt: now}
	}
	if err := a.writeSubscriptions(s); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	subPath := cfg["subscription_path"]
	if subPath == "" {
		subPath = "sub"
	}
	url := a.subscriptionURL(token, cfg)
	path := "/" + subPath + "/" + token
	writeJSON(w, http.StatusOK, rotateResponse{
		Username: username,
		URL:      url,
		Path:     path,
		Rotated:  true,
	})
}

func loadKVFile(path string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	result := map[string]string{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		result[parts[0]] = parts[1]
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return result, nil
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func generateUUID() (string, error) {
	if data, err := os.ReadFile("/proc/sys/kernel/random/uuid"); err == nil {
		value := strings.TrimSpace(string(data))
		if value != "" {
			return value, nil
		}
	}
	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	raw[6] = (raw[6] & 0x0f) | 0x40
	raw[8] = (raw[8] & 0x3f) | 0x80
	hexed := hex.EncodeToString(raw)
	return fmt.Sprintf(
		"%s-%s-%s-%s-%s",
		hexed[0:8],
		hexed[8:12],
		hexed[12:16],
		hexed[16:20],
		hexed[20:32],
	), nil
}

func decodeJSON(body io.ReadCloser, dst any) error {
	defer body.Close()
	dec := json.NewDecoder(body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return err
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, errorResponse{Error: msg})
}

func buildVLESSConfigs(username, uuid string, cfg map[string]string) []string {
	security := "tls"
	if cfg["security"] == "reality" {
		security = "reality"
	}
	alpn := "h2,http/1.1"
	if cfg["transport"] == "ws" {
		alpn = "http/1.1"
	}

	query := make([]string, 0, 16)
	appendKV := func(key, value string) {
		if value == "" {
			return
		}
		query = append(query, key+"="+value)
	}

	appendKV("security", security)
	appendKV("encryption", "none")
	appendKV("alpn", alpn)
	appendKV("headerType", "none")
	fp := cfg["fingerprint"]
	if fp == "" {
		fp = "random"
	}
	appendKV("fp", fp)
	appendKV("type", cfg["transport"])
	if cfg["transport"] == "tcp" {
		appendKV("flow", "xtls-rprx-vision")
	}
	appendKV("sni", stripDomainPort(cfg["domain"]))
	if cfg["transport"] == "ws" || cfg["transport"] == "http" || cfg["transport"] == "xhttp" {
		appendKV("host", cfg["server"])
		appendKV("path", "%2F"+cfg["service_path"])
	}
	if cfg["security"] == "reality" {
		appendKV("pbk", cfg["public_key"])
	}
	if cfg["xray_experimental"] == "ON" && cfg["experimental_user"] == username {
		appendKV("seed", cfg["experimental_test_seed"])
	}
	if cfg["transport"] == "grpc" {
		appendKV("mode", "gun")
		appendKV("serviceName", cfg["service_path"])
	}

	prefix := fmt.Sprintf("vless://%s@%s:%s", uuid, cfg["server"], cfg["port"])
	baseQuery := append([]string{}, query...)
	shortIDs := []string{""}
	if cfg["security"] == "reality" {
		shortIDs = parseShortIDs(cfg["short_ids"])
		if len(shortIDs) == 0 && strings.TrimSpace(cfg["short_id"]) != "" {
			shortIDs = []string{strings.TrimSpace(cfg["short_id"])}
		}
	}
	if len(shortIDs) == 0 {
		shortIDs = []string{""}
	}

	ipv6 := cachedIPv6()
	configs := make([]string, 0, len(shortIDs)*2)
	for i, sid := range shortIDs {
		queryPart := append([]string{}, baseQuery...)
		if cfg["security"] == "reality" && sid != "" {
			queryPart = append(queryPart, "sid="+sid)
		}
		remark := username
		if cfg["security"] == "reality" && i > 0 {
			remark = fmt.Sprintf("%s-sid%d", username, i+1)
		}
		base := fmt.Sprintf("%s?%s#%s", prefix, strings.Join(queryPart, "&"), remark)
		configs = append(configs, base)
		if ipv6 != "" {
			ipv6Config := strings.Replace(base, "@"+cfg["server"]+":", "@["+ipv6+"]:", 1)
			ipv6Config = strings.Replace(ipv6Config, "#"+remark, "#"+remark+"-ipv6", 1)
			configs = append(configs, ipv6Config)
		}
	}
	return configs
}

func parseShortIDs(raw string) []string {
	seen := map[string]struct{}{}
	result := make([]string, 0, 4)
	for _, item := range strings.Split(raw, ",") {
		id := strings.ToLower(strings.TrimSpace(item))
		if id == "" {
			continue
		}
		if len(id)%2 != 0 || len(id) > 16 {
			continue
		}
		valid := true
		for _, ch := range id {
			if (ch < '0' || ch > '9') && (ch < 'a' || ch > 'f') {
				valid = false
				break
			}
		}
		if !valid {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		result = append(result, id)
	}
	return result
}

func stripDomainPort(domain string) string {
	if idx := strings.Index(domain, ":"); idx > 0 {
		return domain[:idx]
	}
	return domain
}

func fetchIPv6() string {
	client := &http.Client{Timeout: 3 * time.Second}
	req, err := http.NewRequest(http.MethodGet, "https://cloudflare.com/cdn-cgi/trace", nil)
	if err != nil {
		return ""
	}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 8*1024))
	if err != nil {
		return ""
	}
	for _, line := range bytes.Split(body, []byte{'\n'}) {
		if bytes.HasPrefix(line, []byte("ip=")) {
			ip := strings.TrimSpace(strings.TrimPrefix(string(line), "ip="))
			if strings.Contains(ip, ":") {
				return ip
			}
		}
	}
	return ""
}
