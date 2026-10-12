package parse

import (
	"net/url"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ParseVlessOrTrojan parses standard vless:// and trojan:// URIs.
func ParseVlessOrTrojan(rawURI string) (*model.Node, error) {
	u, err := url.Parse(rawURI)
	if err != nil {
		return nil, err
	}

	proto := strings.ToLower(u.Scheme)
	server := u.Hostname()
	port, err := strconv.Atoi(u.Port())
	if err != nil || port <= 0 {
		port = 443
	}

	credential := u.User.Username()
	name := CleanText(u.Fragment)
	if name == "" {
		name = proto + "-" + server
	}

	q := u.Query()
	security := q.Get("security")
	if security == "" {
		security = "none"
	}

	network := q.Get("type")
	if network == "" {
		network = "tcp"
	}

	sni := q.Get("sni")
	if sni == "" {
		sni = q.Get("peer")
	}
	if sni == "" {
		sni = server
	}

	node := &model.Node{
		Protocol:    proto,
		Name:        name,
		Server:      server,
		Port:        port,
		Security:    security,
		Network:     network,
		Flow:        q.Get("flow"),
		Path:        q.Get("path"),
		Host:        q.Get("host"),
		ServiceName: q.Get("serviceName"),
		SNI:         sni,
		Fingerprint: q.Get("fp"),
		PublicKey:   q.Get("pbk"),
		ShortID:     q.Get("sid"),
		SpiderX:     q.Get("spx"),
		Insecure:    q.Get("allowInsecure") == "1" || q.Get("insecure") == "1",
	}

	if proto == "vless" {
		node.UUID = credential
	} else {
		node.Password = credential
	}

	if alpnStr := q.Get("alpn"); alpnStr != "" {
		node.ALPN = strings.Split(alpnStr, ",")
	}

	return node, nil
}
