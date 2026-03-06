package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/go-telegram/bot"
	"github.com/go-telegram/bot/models"
)

// ── API types ────────────────────────────────────────────────────────────────

type apiError struct {
	Error string `json:"error"`
}

type usersResponse struct {
	Users []string `json:"users"`
}

type configResponse struct {
	Username string   `json:"username"`
	Configs  []string `json:"configs"`
}

type vlessEncResponse struct {
	Status string `json:"status"`
	Output string `json:"output"`
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

// ── Bot state ────────────────────────────────────────────────────────────────

type vpnBot struct {
	apiURL        string
	apiToken      string
	admins        map[int64]struct{}
	httpClient    *http.Client
	usernameRegex *regexp.Regexp
}

// ── Entry point ──────────────────────────────────────────────────────────────

func main() {
	token := os.Getenv("BOT_TOKEN")
	adminsRaw := os.Getenv("BOT_ADMIN_IDS")
	apiURL := getEnv("VPN_API_URL", "http://vpn-api:8080")
	apiToken := os.Getenv("VPN_API_TOKEN")

	if token == "" {
		log.Fatal("BOT_TOKEN is required")
	}
	if adminsRaw == "" {
		log.Fatal("BOT_ADMIN_IDS is required")
	}
	if apiToken == "" {
		log.Fatal("VPN_API_TOKEN is required")
	}

	vb := &vpnBot{
		apiURL:        strings.TrimRight(apiURL, "/"),
		apiToken:      apiToken,
		admins:        parseAdminIDs(adminsRaw),
		httpClient:    &http.Client{Timeout: 35 * time.Second},
		usernameRegex: regexp.MustCompile(`^[a-zA-Z0-9]{1,32}$`),
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	opts := []bot.Option{
		bot.WithMiddlewares(vb.authMiddleware),
		bot.WithMessageTextHandler("/start", bot.MatchTypeExact, vb.handleHelp),
		bot.WithMessageTextHandler("/help", bot.MatchTypeExact, vb.handleHelp),
		bot.WithMessageTextHandler("/users", bot.MatchTypeExact, vb.handleUsers),
		bot.WithMessageTextHandler("/server", bot.MatchTypeExact, vb.handleServer),
		bot.WithMessageTextHandler("/vlessenc", bot.MatchTypeExact, vb.handleVLESSEnc),
		bot.WithDefaultHandler(vb.handleDefault),
	}

	b, err := bot.New(token, opts...)
	if err != nil {
		log.Fatalf("failed to create bot: %v", err)
	}

	log.Println("telegram bot started")
	b.Start(ctx)
}

// ── Middleware ────────────────────────────────────────────────────────────────

func (vb *vpnBot) authMiddleware(next bot.HandlerFunc) bot.HandlerFunc {
	return func(ctx context.Context, b *bot.Bot, update *models.Update) {
		if update.Message == nil {
			return
		}
		userID := update.Message.From.ID
		if _, ok := vb.admins[userID]; !ok {
			b.SendMessage(ctx, &bot.SendMessageParams{ //nolint:errcheck
				ChatID: update.Message.Chat.ID,
				Text:   fmt.Sprintf("Доступ запрещён: ваш Telegram ID (%d) не в списке администраторов.", userID),
			})
			return
		}
		next(ctx, b, update)
	}
}

// ── Handlers ─────────────────────────────────────────────────────────────────

func (vb *vpnBot) handleHelp(ctx context.Context, b *bot.Bot, update *models.Update) {
	text := strings.Join([]string{
		"Reality-EZPZ Xray Bot",
		"",
		"Доступные команды:",
		"/users — список пользователей",
		"/show <username> — клиентские конфиги",
		"/add <username> — добавить пользователя",
		"/delete <username> — удалить пользователя",
		"/server — конфиг сервера",
		"/vlessenc — тестовые VLESS PQ-параметры",
		"/sub <username> — ссылка подписки",
		"/subrotate <username> — перевыпустить ссылку подписки",
	}, "\n")
	vb.send(ctx, b, update.Message.Chat.ID, text)
}

func (vb *vpnBot) handleUsers(ctx context.Context, b *bot.Bot, update *models.Update) {
	var resp usersResponse
	if err := vb.apiRequest(http.MethodGet, "/v1/users", nil, &resp); err != nil {
		vb.send(ctx, b, update.Message.Chat.ID, "Ошибка получения пользователей: "+err.Error())
		return
	}
	if len(resp.Users) == 0 {
		vb.send(ctx, b, update.Message.Chat.ID, "Пользователи не найдены.")
		return
	}
	vb.send(ctx, b, update.Message.Chat.ID, "Пользователи:\n"+strings.Join(resp.Users, "\n"))
}

func (vb *vpnBot) handleServer(ctx context.Context, b *bot.Bot, update *models.Update) {
	var payload map[string]string
	if err := vb.apiRequest(http.MethodGet, "/v1/server-config", nil, &payload); err != nil {
		vb.send(ctx, b, update.Message.Chat.ID, "Ошибка получения конфига сервера: "+err.Error())
		return
	}
	lines := []string{
		"Конфиг сервера:",
		"Сервер: " + payload["server"],
		"SNI: " + payload["domain"],
		"Порт: " + payload["port"],
		"Транспорт: " + payload["transport"],
		"Безопасность: " + payload["security"],
		"Short IDs: " + payload["short_ids"],
		"Xray version.min: " + payload["xray_version_min"],
		"Experimental: " + payload["xray_experimental"],
		"WARP: " + payload["warp"],
		"Telegram bot: " + payload["tgbot"],
	}
	vb.send(ctx, b, update.Message.Chat.ID, strings.Join(lines, "\n"))
}

func (vb *vpnBot) handleVLESSEnc(ctx context.Context, b *bot.Bot, update *models.Update) {
	var resp vlessEncResponse
	if err := vb.apiRequest(http.MethodPost, "/v1/experimental/vlessenc", map[string]string{}, &resp); err != nil {
		vb.send(ctx, b, update.Message.Chat.ID, "Ошибка vlessenc: "+err.Error())
		return
	}
	if strings.TrimSpace(resp.Output) == "" {
		vb.send(ctx, b, update.Message.Chat.ID, "vlessenc не вернул данные.")
		return
	}
	vb.send(ctx, b, update.Message.Chat.ID, "vlessenc output:\n"+resp.Output)
}

// handleDefault routes parameterised commands: /show, /add, /delete
func (vb *vpnBot) handleDefault(ctx context.Context, b *bot.Bot, update *models.Update) {
	if update.Message == nil {
		return
	}
	text := strings.TrimSpace(update.Message.Text)
	cmd, arg := parseCommand(text)

	switch cmd {
	case "show":
		vb.handleShow(ctx, b, update.Message.Chat.ID, arg)
	case "add":
		vb.handleAdd(ctx, b, update.Message.Chat.ID, arg)
	case "delete":
		vb.handleDelete(ctx, b, update.Message.Chat.ID, arg)
	case "sub":
		vb.handleSubscription(ctx, b, update.Message.Chat.ID, arg)
	case "subrotate":
		vb.handleRotateSubscription(ctx, b, update.Message.Chat.ID, arg)
	default:
		vb.send(ctx, b, update.Message.Chat.ID, "Неизвестная команда. Используйте /help.")
	}
}

func (vb *vpnBot) handleShow(ctx context.Context, b *bot.Bot, chatID int64, username string) {
	if !vb.usernameRegex.MatchString(username) {
		vb.send(ctx, b, chatID, "Использование: /show <username>")
		return
	}
	var resp configResponse
	if err := vb.apiRequest(http.MethodGet, "/v1/users/"+username+"/config", nil, &resp); err != nil {
		vb.send(ctx, b, chatID, "Ошибка получения конфигов: "+err.Error())
		return
	}
	if len(resp.Configs) == 0 {
		vb.send(ctx, b, chatID, "Конфиги не найдены.")
		return
	}
	for i, cfg := range resp.Configs {
		label := "Конфиг"
		if i > 0 {
			label = fmt.Sprintf("Конфиг %d", i+1)
		}
		vb.send(ctx, b, chatID, fmt.Sprintf("%s для %s:\n%s", label, username, cfg))
	}
}

func (vb *vpnBot) handleAdd(ctx context.Context, b *bot.Bot, chatID int64, username string) {
	if !vb.usernameRegex.MatchString(username) {
		vb.send(ctx, b, chatID, "Использование: /add <username>")
		return
	}
	if err := vb.apiRequest(http.MethodPost, "/v1/users", map[string]string{"username": username}, nil); err != nil {
		vb.send(ctx, b, chatID, "Ошибка создания пользователя: "+err.Error())
		return
	}
	vb.send(ctx, b, chatID, fmt.Sprintf("Пользователь %s создан.", username))
}

func (vb *vpnBot) handleDelete(ctx context.Context, b *bot.Bot, chatID int64, username string) {
	if !vb.usernameRegex.MatchString(username) {
		vb.send(ctx, b, chatID, "Использование: /delete <username>")
		return
	}
	if err := vb.apiRequest(http.MethodDelete, "/v1/users/"+username, nil, nil); err != nil {
		vb.send(ctx, b, chatID, "Ошибка удаления пользователя: "+err.Error())
		return
	}
	vb.send(ctx, b, chatID, fmt.Sprintf("Пользователь %s удалён.", username))
}

func (vb *vpnBot) handleSubscription(ctx context.Context, b *bot.Bot, chatID int64, username string) {
	if !vb.usernameRegex.MatchString(username) {
		vb.send(ctx, b, chatID, "Использование: /sub <username>")
		return
	}
	var resp subscriptionResponse
	if err := vb.apiRequest(http.MethodGet, "/v1/users/"+username+"/subscription", nil, &resp); err != nil {
		vb.send(ctx, b, chatID, "Ошибка получения ссылки подписки: "+err.Error())
		return
	}
	vb.send(ctx, b, chatID, fmt.Sprintf("Ссылка подписки для %s:\n%s", username, resp.URL))
}

func (vb *vpnBot) handleRotateSubscription(ctx context.Context, b *bot.Bot, chatID int64, username string) {
	if !vb.usernameRegex.MatchString(username) {
		vb.send(ctx, b, chatID, "Использование: /subrotate <username>")
		return
	}
	var resp rotateResponse
	if err := vb.apiRequest(http.MethodPost, "/v1/users/"+username+"/subscription/rotate", map[string]string{}, &resp); err != nil {
		vb.send(ctx, b, chatID, "Ошибка ротации ссылки подписки: "+err.Error())
		return
	}
	vb.send(ctx, b, chatID, fmt.Sprintf("Новая ссылка подписки для %s:\n%s", username, resp.URL))
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func (vb *vpnBot) send(ctx context.Context, b *bot.Bot, chatID int64, text string) {
	if _, err := b.SendMessage(ctx, &bot.SendMessageParams{
		ChatID: chatID,
		Text:   text,
	}); err != nil {
		log.Printf("sendMessage error: %v", err)
	}
}

func (vb *vpnBot) apiRequest(method, path string, body any, out any) error {
	var payload io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return err
		}
		payload = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, vb.apiURL+path, payload)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+vb.apiToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := vb.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		var apiErr apiError
		if err := json.NewDecoder(resp.Body).Decode(&apiErr); err != nil || apiErr.Error == "" {
			return fmt.Errorf("HTTP %d", resp.StatusCode)
		}
		return fmt.Errorf("%s", apiErr.Error)
	}
	if out != nil {
		if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
			return err
		}
	}
	return nil
}

func parseCommand(text string) (string, string) {
	fields := strings.Fields(text)
	if len(fields) == 0 {
		return "", ""
	}
	command := strings.TrimPrefix(fields[0], "/")
	if idx := strings.Index(command, "@"); idx > 0 {
		command = command[:idx]
	}
	command = strings.ToLower(command)
	if len(fields) == 1 {
		return command, ""
	}
	return command, strings.TrimSpace(strings.Join(fields[1:], " "))
}

func parseAdminIDs(value string) map[int64]struct{} {
	result := map[int64]struct{}{}
	for _, item := range strings.Split(value, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		id, err := strconv.ParseInt(item, 10, 64)
		if err != nil || id <= 0 {
			continue
		}
		result[id] = struct{}{}
	}
	return result
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
