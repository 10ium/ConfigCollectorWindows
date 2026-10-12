package model

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

// Node represents a protocol-neutral proxy node extracted from raw configurations.
type Node struct {
	ID          string            `json:"id"`
	Protocol    string            `json:"protocol"` // vless, vmess, trojan, ss, hysteria2, tuic, wireguard, socks5, etc.
	Name        string            `json:"name"`
	Server      string            `json:"server"`
	Port        int               `json:"port"`
	UUID        string            `json:"uuid,omitempty"`
	Password    string            `json:"password,omitempty"`
	Method      string            `json:"method,omitempty"` // for shadowsocks
	Security    string            `json:"security,omitempty"` // tls, reality, none
	Flow        string            `json:"flow,omitempty"`
	Network     string            `json:"network,omitempty"` // tcp, ws, grpc, xhttp, etc.
	Path        string            `json:"path,omitempty"`
	Host        string            `json:"host,omitempty"`
	ServiceName string            `json:"service_name,omitempty"`
	SNI         string            `json:"sni,omitempty"`
	Fingerprint string            `json:"fingerprint,omitempty"` // utls fingerprint
	ALPN        []string          `json:"alpn,omitempty"`
	Insecure    bool              `json:"insecure,omitempty"`

	// Reality specific
	PublicKey string `json:"public_key,omitempty"`
	ShortID   string `json:"short_id,omitempty"`
	SpiderX   string `json:"spider_x,omitempty"`

	// Hysteria specific
	AuthStr      string `json:"auth_str,omitempty"`
	Obfs         string `json:"obfs,omitempty"`
	ObfsPassword string `json:"obfs_password,omitempty"`

	// TUIC specific
	CongestionControl string `json:"congestion_control,omitempty"`
	UDP               bool   `json:"udp,omitempty"`

	// WireGuard / Amnezia specific
	PrivateKey   string `json:"private_key,omitempty"`
	Reserved     []int  `json:"reserved,omitempty"`
	MTU          int    `json:"mtu,omitempty"`
	AmneziaNoise string `json:"amnezia_noise,omitempty"`

	// Source tracking
	SourceType string    `json:"source_type"` // telegram, subscription, local_file
	SourceURI  string    `json:"source_uri"`
	Discovered time.Time `json:"discovered_at"`

	// Test outcomes & scoring
	Result TestResult `json:"result"`
}

// TestResult encapsulates all active and historical probe measurements.
type TestResult struct {
	Tested            bool      `json:"tested"`
	Alive             bool      `json:"alive"`
	PingMs            float64   `json:"ping_ms"`
	PingMicroseconds  int64     `json:"ping_micros"`
	ExitIP            string    `json:"exit_ip"`
	CountryCode       string    `json:"country_code"`
	FlagEmoji         string    `json:"flag_emoji"`
	GeminiStatus      string    `json:"gemini_status"` // ok, blocked, signin_required, untested
	YouTubeStatus     string    `json:"youtube_status"`
	TelegramStatus    string    `json:"telegram_status"`
	UDPSupported      bool      `json:"udp_supported"`
	PacketLossPercent float64   `json:"packet_loss_percent"`
	JitterMs          float64   `json:"jitter_ms"`
	FraudScore        int       `json:"fraud_score"` // 0 (clean) to 100 (abused)
	DownloadSpeedKBps float64   `json:"download_speed_kbps"`
	UploadSpeedKBps   float64   `json:"upload_speed_kbps"`
	Score             float64   `json:"score"` // 0.00000 - 100.00000
	TestedAt          time.Time `json:"tested_at"`
	Error             string    `json:"error,omitempty"`
}

// TechnicalFingerprint generates a deterministic hash representing the technical endpoint.
// Two configs with different names or emojis but pointing to the same server/port/credentials
// produce the same fingerprint to eliminate duplicates.
func (n *Node) TechnicalFingerprint() string {
	raw := fmt.Sprintf("%s|%s|%d|%s|%s|%s|%s|%s|%s|%s",
		strings.ToLower(n.Protocol),
		strings.ToLower(n.Server),
		n.Port,
		n.UUID,
		n.Password,
		strings.ToLower(n.Network),
		strings.ToLower(n.SNI),
		n.Path,
		n.PublicKey,
		n.ShortID,
	)
	hasher := md5.New()
	hasher.Write([]byte(raw))
	return hex.EncodeToString(hasher.Sum(nil))
}

// FormattedName generates the final display/export proxy name based on user template.
func (n *Node) FormattedName(template string) string {
	if template == "" {
		template = "{flag} {country} | {proto} | {score}★"
	}
	res := template
	flag := n.Result.FlagEmoji
	if flag == "" {
		flag = "🌐"
	}
	country := n.Result.CountryCode
	if country == "" {
		country = "UN"
	}
	res = strings.ReplaceAll(res, "{flag}", flag)
	res = strings.ReplaceAll(res, "{country}", country)
	res = strings.ReplaceAll(res, "{proto}", strings.ToUpper(n.Protocol))
	res = strings.ReplaceAll(res, "{ping}", fmt.Sprintf("%.0fms", n.Result.PingMs))
	res = strings.ReplaceAll(res, "{score}", fmt.Sprintf("%.1f", n.Result.Score))
	if strings.TrimSpace(n.Name) != "" && strings.Contains(res, "{name}") {
		res = strings.ReplaceAll(res, "{name}", n.Name)
	}
	return strings.TrimSpace(res)
}
