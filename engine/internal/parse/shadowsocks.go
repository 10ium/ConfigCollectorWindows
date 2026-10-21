package parse

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ParseShadowsocks parses both SIP002 and legacy Shadowsocks URIs.
func ParseShadowsocks(rawURI string) (*model.Node, error) {
	rest := strings.TrimPrefix(rawURI, "ss://")
	name := ""
	if hashIdx := strings.Index(rest, "#"); hashIdx != -1 {
		name = CleanText(rest[hashIdx+1:])
		rest = rest[:hashIdx]
	}

	var method, password, server string
	var port int = 8388

	if strings.Contains(rest, "@") {
		// SIP002 format: ss://base64(method:password)@server:port
		atIdx := strings.LastIndex(rest, "@")
		userInfo := rest[:atIdx]
		hostPort := rest[atIdx+1:]

		// Handle query params on hostPort
		if qIdx := strings.Index(hostPort, "?"); qIdx != -1 {
			hostPort = hostPort[:qIdx]
		}

		// Decode userInfo if base64 encoded
		if strings.Contains(userInfo, ":") {
			parts := strings.SplitN(userInfo, ":", 2)
			method, password = parts[0], parts[1]
		} else {
			decoded, ok := tryDecodeBase64(userInfo)
			if ok && strings.Contains(decoded, ":") {
				parts := strings.SplitN(decoded, ":", 2)
				method, password = parts[0], parts[1]
			}
		}

		colIdx := strings.LastIndex(hostPort, ":")
		if colIdx != -1 {
			server = strings.Trim(hostPort[:colIdx], "[]")
			if p, err := strconv.Atoi(hostPort[colIdx+1:]); err == nil {
				port = p
			}
		}
	} else {
		// Legacy format: ss://base64(method:password@server:port)
		decoded, ok := tryDecodeBase64(rest)
		if !ok || !strings.Contains(decoded, "@") {
			return nil, fmt.Errorf("invalid legacy shadowsocks uri")
		}
		atIdx := strings.LastIndex(decoded, "@")
		auth := decoded[:atIdx]
		hostPort := decoded[atIdx+1:]

		if strings.Contains(auth, ":") {
			parts := strings.SplitN(auth, ":", 2)
			method, password = parts[0], parts[1]
		}

		colIdx := strings.LastIndex(hostPort, ":")
		if colIdx != -1 {
			server = strings.Trim(hostPort[:colIdx], "[]")
			if p, err := strconv.Atoi(hostPort[colIdx+1:]); err == nil {
				port = p
			}
		}
	}

	if server == "" || password == "" {
		return nil, fmt.Errorf("missing server or password in ss uri")
	}

	if name == "" {
		name = "ss-" + server
	}

	return &model.Node{
		Protocol: "ss",
		Name:     name,
		Server:   server,
		Port:     port,
		Method:   method,
		Password: password,
	}, nil
}

// ParseTelegramProxy parses tg://socks, tg://proxy, and https://t.me/proxy URIs.
func ParseTelegramProxy(rawURI string) (*model.Node, error) {
	cleanURI := strings.Replace(rawURI, "https://t.me/", "tg://", 1)
	cleanURI = strings.Replace(cleanURI, "http://t.me/", "tg://", 1)
	u, err := url.Parse(cleanURI)
	if err != nil {
		return nil, err
	}

	q := u.Query()
	server := q.Get("server")
	port, _ := strconv.Atoi(q.Get("port"))
	if server == "" || port <= 0 {
		return nil, fmt.Errorf("invalid telegram proxy params")
	}

	isMTProto := strings.Contains(strings.ToLower(u.Host), "proxy") || strings.Contains(strings.ToLower(u.Path), "proxy")
	proto := "tg-socks"
	secret := q.Get("secret")
	if secret != "" || isMTProto {
		proto = "mtproto"
	}
	if secret == "" {
		secret = q.Get("pass")
	}

	return &model.Node{
		Protocol:        proto,
		Category:        "telegram",
		IsTelegramProxy: true,
		Name:            "TG-" + strings.ToUpper(proto) + "-" + server,
		Server:          server,
		Port:            port,
		UUID:            q.Get("user"),
		Password:        secret,
	}, nil
}
