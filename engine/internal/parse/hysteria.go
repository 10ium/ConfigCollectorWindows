package parse

import (
	"net/url"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ParseHysteria parses hysteria2://, hy2://, and legacy hysteria:// links.
func ParseHysteria(rawURI string) (*model.Node, error) {
	cleanURI := rawURI
	proto := "hysteria2"
	if strings.HasPrefix(strings.ToLower(cleanURI), "hy2://") {
		cleanURI = "hysteria2://" + cleanURI[6:]
	} else if strings.HasPrefix(strings.ToLower(cleanURI), "hysteria://") {
		proto = "hysteria"
	}

	u, err := url.Parse(cleanURI)
	if err != nil {
		return nil, err
	}

	server := u.Hostname()
	port, err := strconv.Atoi(u.Port())
	if err != nil || port <= 0 {
		port = 443
	}

	password := u.User.Username()
	if pass, ok := u.User.Password(); ok && password == "" {
		password = pass
	}

	q := u.Query()
	name := CleanText(u.Fragment)
	if name == "" {
		name = proto + "-" + server
	}

	sni := q.Get("sni")
	if sni == "" {
		sni = q.Get("peer")
	}
	if sni == "" {
		sni = server
	}

	node := &model.Node{
		Protocol:     proto,
		Name:         name,
		Server:       server,
		Port:         port,
		Password:     password,
		SNI:          sni,
		Insecure:     q.Get("insecure") == "1" || q.Get("insecure") == "true",
		Obfs:         q.Get("obfs"),
		ObfsPassword: q.Get("obfs-password"),
		AuthStr:      q.Get("auth"),
	}

	if alpnStr := q.Get("alpn"); alpnStr != "" {
		node.ALPN = strings.Split(alpnStr, ",")
	} else {
		node.ALPN = []string{"h3"}
	}

	return node, nil
}

// ParseTuic parses tuic:// links.
func ParseTuic(rawURI string) (*model.Node, error) {
	u, err := url.Parse(rawURI)
	if err != nil {
		return nil, err
	}

	server := u.Hostname()
	port, err := strconv.Atoi(u.Port())
	if err != nil || port <= 0 {
		port = 443
	}

	uuid := u.User.Username()
	password, _ := u.User.Password()

	q := u.Query()
	name := CleanText(u.Fragment)
	if name == "" {
		name = "tuic-" + server
	}

	sni := q.Get("sni")
	if sni == "" {
		sni = server
	}

	node := &model.Node{
		Protocol:          "tuic",
		Name:              name,
		Server:            server,
		Port:              port,
		UUID:              uuid,
		Password:          password,
		CongestionControl: q.Get("congestion_control"),
		SNI:               sni,
		UDP:               true,
	}

	if alpnStr := q.Get("alpn"); alpnStr != "" {
		node.ALPN = strings.Split(alpnStr, ",")
	} else {
		node.ALPN = []string{"h3"}
	}

	return node, nil
}
