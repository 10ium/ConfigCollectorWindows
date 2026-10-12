package parse

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// SupportedSchemes contains the complete list of 43 URI protocol schemes supported by cf_decryptor_bot.
var SupportedSchemes = []string{
	"vless", "vmess", "trojan", "ss", "ssr", "hysteria2", "hy2", "hysteria",
	"wireguard", "wg", "masque", "tuic", "snell", "shadowtls", "anytls",
	"ssh", "socks5", "socks", "http", "https", "vpn", "naive", "tailcat",
	// DNS tunnel protocols
	"dns", "nm-dns", "nm-vless", "slipnet-enc", "slipnet", "slipstream",
	"dnstt", "dnst", "dnstunnel", "vaydns", "stormdns", "cottendns",
	"masterdns", "masterdnsvpn", "noizdns", "slowdns", "ssh-dns", "dns-ssh",
	"ssh-over-dns", "whitedns", "tg", "ssc", "darktunnel",
}

var dnsProtocolsSet = map[string]bool{
	"dns": true, "nm-dns": true, "nm-vless": true, "slipnet-enc": true,
	"slipnet": true, "slipstream": true, "dnstt": true, "dnst": true,
	"dnstunnel": true, "vaydns": true, "stormdns": true, "cottendns": true,
	"masterdns": true, "masterdnsvpn": true, "noizdns": true, "slowdns": true,
	"ssh-dns": true, "dns-ssh": true, "ssh-over-dns": true, "whitedns": true,
}

// BuildSchemesRegex generates a consolidated regular expression matching all supported protocol links.
func BuildSchemesRegex() *regexp.Regexp {
	escaped := make([]string, len(SupportedSchemes))
	for i, s := range SupportedSchemes {
		escaped[i] = regexp.QuoteMeta(s)
	}
	pattern := fmt.Sprintf(`(?i)(?:%s)://[^\s<>"'\r\n]+`, strings.Join(escaped, "|"))
	return regexp.MustCompile(pattern)
}

// ParseGenericURI parses extended protocols: snell, shadowtls, anytls, ssh, masque, ssr, and dns-tunnels.
func ParseGenericURI(rawURI string) (*model.Node, error) {
	u, err := url.Parse(rawURI)
	if err != nil {
		return nil, err
	}

	scheme := strings.ToLower(u.Scheme)

	// DNS Tunnel Schemes
	if dnsProtocolsSet[scheme] {
		server := u.Hostname()
		if server == "" {
			server = "dns-tunnel"
		}
		port, _ := strconv.Atoi(u.Port())
		if port <= 0 {
			port = 53
		}
		q := u.Query()
		name := CleanText(u.Fragment)
		if name == "" {
			name = scheme + "-" + server
		}
		return &model.Node{
			Protocol:    scheme,
			Name:        name,
			Server:      server,
			Port:        port,
			IsDNSTunnel: true,
			Domain:      q.Get("domain"),
			DNSTTPubKey: q.Get("pubkey"),
			Network:     "udp",
			UDP:         true,
		}, nil
	}

	server := u.Hostname()
	port, _ := strconv.Atoi(u.Port())
	q := u.Query()
	name := CleanText(u.Fragment)
	if name == "" {
		name = scheme + "-" + server
	}

	switch scheme {
	case "snell":
		if port <= 0 {
			port = 443
		}
		return &model.Node{
			Protocol: "snell",
			Name:     name,
			Server:   server,
			Port:     port,
			PSK:      u.User.Username(),
			Version:  q.Get("version"),
			Obfs:     q.Get("obfs"),
		}, nil

	case "shadowtls":
		if port <= 0 {
			port = 443
		}
		return &model.Node{
			Protocol: "shadowtls",
			Name:     name,
			Server:   server,
			Port:     port,
			Password: u.User.Username(),
			SNI:      q.Get("sni"),
			Version:  q.Get("version"),
		}, nil

	case "anytls":
		if port <= 0 {
			port = 443
		}
		return &model.Node{
			Protocol: "anytls",
			Name:     name,
			Server:   server,
			Port:     port,
			Password: u.User.Username(),
			SNI:      q.Get("sni"),
		}, nil

	case "ssh":
		if port <= 0 {
			port = 22
		}
		pass, _ := u.User.Password()
		return &model.Node{
			Protocol: "ssh",
			Name:     name,
			Server:   server,
			Port:     port,
			Username: u.User.Username(),
			Password: pass,
		}, nil

	case "masque":
		if port <= 0 {
			port = 443
		}
		return &model.Node{
			Protocol:   "masque",
			Name:       name,
			Server:     server,
			Port:       port,
			PrivateKey: u.User.Username(),
			SNI:        q.Get("sni"),
			Network:    q.Get("transport"),
		}, nil

	case "ssr":
		return parseSSR(rawURI)
	}

	return nil, fmt.Errorf("unhandled generic scheme: %s", scheme)
}

func parseSSR(rawURI string) (*model.Node, error) {
	rest := strings.TrimPrefix(rawURI, "ssr://")
	decoded, ok := tryDecodeBase64(rest)
	if !ok {
		return nil, fmt.Errorf("failed to decode ssr base64")
	}

	// Format: server:port:protocol:method:obfs:password_base64/?params
	mainParts := strings.SplitN(decoded, "/?", 2)
	parts := strings.Split(mainParts[0], ":")
	if len(parts) < 6 {
		return nil, fmt.Errorf("invalid ssr format")
	}

	server := parts[0]
	port, _ := strconv.Atoi(parts[1])
	method := parts[3]
	obfs := parts[4]

	passBytes, _ := base64.RawURLEncoding.DecodeString(parts[5])
	password := string(passBytes)

	name := "ssr-" + server
	if len(mainParts) > 1 {
		q, _ := url.ParseQuery(mainParts[1])
		if remarks := q.Get("remarks"); remarks != "" {
			if rBytes, err := base64.RawURLEncoding.DecodeString(remarks); err == nil {
				name = CleanText(string(rBytes))
			}
		}
	}

	return &model.Node{
		Protocol: "ssr",
		Name:     name,
		Server:   server,
		Port:     port,
		Method:   method,
		Password: password,
		Obfs:     obfs,
	}, nil
}
