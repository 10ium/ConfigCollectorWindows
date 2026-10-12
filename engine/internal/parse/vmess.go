package parse

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

type vmessJSON struct {
	V    interface{} `json:"v"`
	Ps   string      `json:"ps"`
	Add  string      `json:"add"`
	Port interface{} `json:"port"`
	ID   string      `json:"id"`
	Aid  interface{} `json:"aid"`
	Scy  string      `json:"scy"`
	Net  string      `json:"net"`
	Type string      `json:"type"`
	Host string      `json:"host"`
	Path string      `json:"path"`
	TLS  interface{} `json:"tls"`
	SNI  string      `json:"sni"`
	ALPN string      `json:"alpn"`
	FP   string      `json:"fp"`
}

// ParseVmess parses a vmess://base64 URI into a Node.
func ParseVmess(rawURI string) (*model.Node, error) {
	trimmed := strings.TrimPrefix(rawURI, "vmess://")
	decoded, ok := tryDecodeBase64(trimmed)
	if !ok {
		return nil, fmt.Errorf("failed to base64 decode vmess payload")
	}

	var v vmessJSON
	if err := json.Unmarshal([]byte(decoded), &v); err != nil {
		return nil, fmt.Errorf("failed to unmarshal vmess json: %w", err)
	}

	port := 443
	switch p := v.Port.(type) {
	case float64:
		port = int(p)
	case string:
		if parsed, err := strconv.Atoi(p); err == nil {
			port = parsed
		}
	}

	name := CleanText(v.Ps)
	if name == "" {
		name = "vmess-" + v.Add
	}

	security := "none"
	if v.TLS == "tls" || v.TLS == true || v.TLS == "1" {
		security = "tls"
	}

	network := v.Net
	if network == "" {
		network = "tcp"
	}

	sni := v.SNI
	if sni == "" {
		sni = v.Host
	}
	if sni == "" {
		sni = v.Add
	}

	node := &model.Node{
		Protocol:    "vmess",
		Name:        name,
		Server:      v.Add,
		Port:        port,
		UUID:        v.ID,
		Security:    security,
		Network:     network,
		Path:        v.Path,
		Host:        v.Host,
		SNI:         sni,
		Fingerprint: v.FP,
	}

	if v.ALPN != "" {
		node.ALPN = strings.Split(v.ALPN, ",")
	}

	return node, nil
}
