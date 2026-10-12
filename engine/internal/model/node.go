package model

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

// Node represents a protocol-neutral proxy node extracted from raw configurations or decrypted files.
type Node struct {
	ID          string   `json:"id"`
	Protocol    string   `json:"protocol"` // vless, vmess, trojan, ss, ssr, hysteria2, tuic, wireguard, masque, snell, shadowtls, anytls, ssh, socks5, http, dns-tunnel, etc.
	Name        string   `json:"name"`
	Server      string   `json:"server"`
	Port        int      `json:"port"`
	UUID        string   `json:"uuid,omitempty"`
	Password    string   `json:"password,omitempty"`
	Method      string   `json:"method,omitempty"`   // for shadowsocks/ssr
	Security    string   `json:"security,omitempty"` // tls, reality, shadowtls, none
	Flow        string   `json:"flow,omitempty"`
	Network     string   `json:"network,omitempty"` // tcp, ws, grpc, xhttp, splithttp, h2, quic
	Path        string   `json:"path,omitempty"`
	Host        string   `json:"host,omitempty"`
	ServiceName string   `json:"service_name,omitempty"`
	SNI         string   `json:"sni,omitempty"`
	Fingerprint string   `json:"fingerprint,omitempty"` // utls fingerprint: chrome, firefox, safari, randomized, etc.
	ALPN        []string `json:"alpn,omitempty"`
	Insecure    bool     `json:"insecure,omitempty"`

	// Reality specific
	PublicKey string `json:"public_key,omitempty"`
	ShortID   string `json:"short_id,omitempty"`
	SpiderX   string `json:"spider_x,omitempty"`

	// Hysteria specific
	AuthStr      string `json:"auth_str,omitempty"`
	Obfs         string `json:"obfs,omitempty"`
	ObfsPassword string `json:"obfs_password,omitempty"`
	UpMbps       int    `json:"up_mbps,omitempty"`
	DownMbps     int    `json:"down_mbps,omitempty"`

	// TUIC specific
	CongestionControl string `json:"congestion_control,omitempty"`
	UDPRelayMode      string `json:"udp_relay_mode,omitempty"`
	ZeroRTTHandshake  bool   `json:"zero_rtt_handshake,omitempty"`

	// WireGuard & AmneziaWG specific
	PrivateKey   string `json:"private_key,omitempty"`
	PresharedKey string `json:"preshared_key,omitempty"`
	LocalAddress string `json:"local_address,omitempty"`
	Reserved     []int  `json:"reserved,omitempty"`
	MTU          int    `json:"mtu,omitempty"`
	JC           int    `json:"jc,omitempty"`
	JMin         int    `json:"jmin,omitempty"`
	JMax         int    `json:"jmax,omitempty"`
	S1           int    `json:"s1,omitempty"`
	S2           int    `json:"s2,omitempty"`
	H1           string `json:"h1,omitempty"`
	H2           string `json:"h2,omitempty"`

	// Snell / ShadowTLS / AnyTLS
	PSK     string `json:"psk,omitempty"`
	Version string `json:"version,omitempty"`

	// SSH specific
	Username     string `json:"username,omitempty"`
	Payload      string `json:"payload,omitempty"`
	ProxyServer  string `json:"proxy_server,omitempty"`
	ProxyPort    int    `json:"proxy_port,omitempty"`

	// DNS Tunnel specific (dnstt, slipstream, slowdns, etc.)
	IsDNSTunnel  bool     `json:"is_dns_tunnel,omitempty"`
	Domain       string   `json:"domain,omitempty"`
	Resolvers    []string `json:"resolvers,omitempty"`
	DNSTTPubKey  string   `json:"dnstt_pubkey,omitempty"`

	// OpenVPN specific
	Proto        string `json:"proto,omitempty"` // udp or tcp
	AuthUser     string `json:"auth_user,omitempty"`
	AuthPass     string `json:"auth_pass,omitempty"`
	CA           string `json:"ca,omitempty"`
	Cert         string `json:"cert,omitempty"`
	Key          string `json:"key,omitempty"`
	TLSAuth      string `json:"tls_auth,omitempty"`
	TLSCrypt     string `json:"tls_crypt,omitempty"`
	TLSCryptV2   string `json:"tls_crypt_v2,omitempty"`
	KeyDirection string `json:"key_direction,omitempty"`
	Cipher       string `json:"cipher,omitempty"`
	OpenVPNAuth  string `json:"openvpn_auth,omitempty"`

	// Expiry & Validity metadata
	ExpiryTimestamp int64 `json:"expiry_timestamp,omitempty"`
	IsExpired       bool  `json:"is_expired,omitempty"`
	IsBroken        bool  `json:"is_broken,omitempty"`

	// Metadata and Origin
	SourceType string    `json:"source_type"` // telegram, subscription, local_file, decrypted_file
	SourceURI  string    `json:"source_uri"`
	Discovered time.Time `json:"discovered_at"`

	// Test outcomes & scoring
	Result TestResult `json:"result"`
}

// IsMihomoCompatible checks whether this node protocol and features are natively supported by Mihomo.
func (n *Node) IsMihomoCompatible() bool {
	proto := strings.ToLower(n.Protocol)
	switch proto {
	case "vless", "vmess", "trojan", "ss", "shadowsocks", "ssr", "hysteria", "hysteria2", "hy2",
		"tuic", "wireguard", "snell", "shadowtls", "ssh", "socks5", "http", "openvpn",
		"masque", "shadowquic", "trusttunnel", "mieru", "anytls", "sudoku":
		return true
	default:
		return false
	}
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
func (n *Node) TechnicalFingerprint() string {
	raw := fmt.Sprintf("%s|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s",
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
		n.Domain,
		n.PrivateKey,
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
