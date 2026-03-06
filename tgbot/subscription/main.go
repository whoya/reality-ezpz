package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ── Types ─────────────────────────────────────────────────────────────────────

type subscriptions struct {
	Version int                     `json:"version"`
	Users   map[string]subUserEntry `json:"users"`
}

type subUserEntry struct {
	Token     string `json:"token"`
	CreatedAt string `json:"created_at"`
	RotatedAt string `json:"rotated_at"`
}

// ── Entry point ───────────────────────────────────────────────────────────────

func main() {
	configPath := getEnv("CONFIG_PATH", "/opt/reality-ezpz")

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/sub/", func(w http.ResponseWriter, r *http.Request) {
		handleSub(w, r, configPath)
	})

	listenAddr := getEnv("SUB_LISTEN", ":8081")
	server := &http.Server{
		Addr:              listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("subscription-api listening on %s", listenAddr)
	log.Fatal(server.ListenAndServe())
}

// ── Handlers ──────────────────────────────────────────────────────────────────

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}` + "\n"))
}

func handleSub(w http.ResponseWriter, r *http.Request, configPath string) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	token := strings.TrimPrefix(r.URL.Path, "/sub/")
	if token == "" || strings.Contains(token, "/") {
		http.NotFound(w, r)
		return
	}

	cfg, err := loadKVFile(filepath.Join(configPath, "config"))
	if err != nil {
		// Do not reveal details; treat as 404 for public endpoint
		http.NotFound(w, r)
		return
	}

	users, err := loadKVFile(filepath.Join(configPath, "users"))
	if err != nil {
		http.NotFound(w, r)
		return
	}

	subs, err := loadSubscriptions(filepath.Join(configPath, "subscriptions.json"))
	if err != nil {
		http.NotFound(w, r)
		return
	}

	// Find user by token
	username := ""
	for u, entry := range subs.Users {
		if entry.Token == token {
			username = u
			break
		}
	}
	if username == "" {
		http.NotFound(w, r)
		return
	}

	// Verify user still exists
	uuid, exists := users[username]
	if !exists {
		http.NotFound(w, r)
		return
	}

	configs := buildVLESSConfigs(username, uuid, cfg)
	if len(configs) == 0 {
		http.NotFound(w, r)
		return
	}

	// Encode: join with \n, append \n, base64
	joined := strings.Join(configs, "\n") + "\n"
	encoded := base64.StdEncoding.EncodeToString([]byte(joined))

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store, private")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)

	if r.Method == http.MethodGet {
		_, _ = io.WriteString(w, encoded)
	}
}

// ── VLESS config generation (mirrors tgbot/api buildVLESSConfigs) ─────────────

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

	ipv6 := fetchIPv6Once()
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

// fetchIPv6Once performs a single best-effort fetch of the server's IPv6.
// subscription-api is a per-request stateless service; no caching needed for MVP.
func fetchIPv6Once() string {
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

// ── Storage helpers ───────────────────────────────────────────────────────────

func loadSubscriptions(path string) (*subscriptions, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var s subscriptions
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	if s.Users == nil {
		s.Users = map[string]subUserEntry{}
	}
	return &s, nil
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

// ── Util ──────────────────────────────────────────────────────────────────────

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
