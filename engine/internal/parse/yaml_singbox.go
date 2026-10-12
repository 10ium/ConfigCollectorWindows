package parse

import (
	"bufio"
	"encoding/json"
	"strconv"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
	"gopkg.in/yaml.v3"
)

// ParseMihomoYaml extracts all proxies defined inside a Clash/Mihomo YAML file.
func ParseMihomoYaml(yamlContent, sourceURI string) []*model.Node {
	var root struct {
		Proxies []map[string]interface{} `yaml:"proxies"`
	}

	if err := yaml.Unmarshal([]byte(yamlContent), &root); err != nil {
		return nil
	}

	var nodes []*model.Node
	for _, p := range root.Proxies {
		node := parseYamlProxyItem(p, sourceURI)
		if node != nil {
			nodes = append(nodes, node)
		}
	}
	return nodes
}

func parseYamlProxyItem(p map[string]interface{}, sourceURI string) *model.Node {
	name, _ := p["name"].(string)
	proto, _ := p["type"].(string)
	server, _ := p["server"].(string)
	port := 0
	switch v := p["port"].(type) {
	case int:
		port = v
	case float64:
		port = int(v)
	}

	if server == "" || port <= 0 {
		return nil
	}

	node := &model.Node{
		Protocol:   strings.ToLower(proto),
		Name:       CleanText(name),
		Server:     server,
		Port:       port,
		SourceType: "clash_yaml",
		SourceURI:  sourceURI,
	}

	if uuid, ok := p["uuid"].(string); ok {
		node.UUID = uuid
	}
	if password, ok := p["password"].(string); ok {
		node.Password = password
	}
	if cipher, ok := p["cipher"].(string); ok {
		node.Method = cipher
	}
	if sni, ok := p["servername"].(string); ok {
		node.SNI = sni
	}
	if network, ok := p["network"].(string); ok {
		node.Network = network
	}
	if tls, ok := p["tls"].(bool); ok && tls {
		node.Security = "tls"
	}

	// Reality options
	if ro, ok := p["reality-opts"].(map[string]interface{}); ok {
		node.Security = "reality"
		if pbk, ok := ro["public-key"].(string); ok {
			node.PublicKey = pbk
		}
		if sid, ok := ro["short-id"].(string); ok {
			node.ShortID = sid
		}
	}

	// WebSocket options
	if wo, ok := p["ws-opts"].(map[string]interface{}); ok {
		if path, ok := wo["path"].(string); ok {
			node.Path = path
		}
		if headers, ok := wo["headers"].(map[string]interface{}); ok {
			if host, ok := headers["Host"].(string); ok {
				node.Host = host
			}
		}
	}

	return node
}

// ParseSingboxJSON extracts outbounds from a Sing-box JSON configuration.
func ParseSingboxJSON(jsonContent, sourceURI string) []*model.Node {
	var root struct {
		Outbounds []map[string]interface{} `json:"outbounds"`
	}

	if err := json.Unmarshal([]byte(jsonContent), &root); err != nil {
		return nil
	}

	var nodes []*model.Node
	for _, ob := range root.Outbounds {
		proto, _ := ob["type"].(string)
		tag, _ := ob["tag"].(string)
		server, _ := ob["server"].(string)
		port := 0
		switch v := ob["server_port"].(type) {
		case float64:
			port = int(v)
		case int:
			port = v
		}

		if server == "" || port <= 0 {
			continue
		}

		node := &model.Node{
			Protocol:   strings.ToLower(proto),
			Name:       CleanText(tag),
			Server:     server,
			Port:       port,
			SourceType: "singbox_json",
			SourceURI:  sourceURI,
		}

		if uuid, ok := ob["uuid"].(string); ok {
			node.UUID = uuid
		}
		if password, ok := ob["password"].(string); ok {
			node.Password = password
		}
		if method, ok := ob["method"].(string); ok {
			node.Method = method
		}

		// TLS settings
		if tlsObj, ok := ob["tls"].(map[string]interface{}); ok {
			if enabled, ok := tlsObj["enabled"].(bool); ok && enabled {
				node.Security = "tls"
			}
			if serverName, ok := tlsObj["server_name"].(string); ok {
				node.SNI = serverName
			}
			if reality, ok := tlsObj["reality"].(map[string]interface{}); ok {
				if rEnabled, ok := reality["enabled"].(bool); ok && rEnabled {
					node.Security = "reality"
					if pbk, ok := reality["public_key"].(string); ok {
						node.PublicKey = pbk
					}
					if sid, ok := reality["short_id"].(string); ok {
						node.ShortID = sid
					}
				}
			}
		}

		nodes = append(nodes, node)
	}

	return nodes
}

// ParseWireGuardConf parses standard WireGuard .conf file sections.
func ParseWireGuardConf(confContent, sourceURI string) []*model.Node {
	scanner := bufio.NewScanner(strings.NewReader(confContent))
	var privKey, address string
	var pubKey, endpoint string
	var port int = 51820
	var reserved []int

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.ToLower(strings.TrimSpace(parts[0]))
		val := strings.TrimSpace(parts[1])

		switch key {
		case "privatekey":
			privKey = val
		case "address":
			address = val
		case "publickey":
			pubKey = val
		case "endpoint":
			if col := strings.LastIndex(val, ":"); col != -1 {
				endpoint = val[:col]
				port, _ = strconv.Atoi(val[col+1:])
			} else {
				endpoint = val
			}
		case "reserved":
			resParts := strings.Split(val, ",")
			for _, rp := range resParts {
				if num, err := strconv.Atoi(strings.TrimSpace(rp)); err == nil {
					reserved = append(reserved, num)
				}
			}
		}
	}

	if endpoint == "" || (privKey == "" && pubKey == "") {
		return nil
	}

	return []*model.Node{
		{
			Protocol:     "wireguard",
			Name:         "WG-" + endpoint,
			Server:       endpoint,
			Port:         port,
			PrivateKey:   privKey,
			PublicKey:    pubKey,
			LocalAddress: address,
			Reserved:     reserved,
			SourceType:   "wireguard_conf",
			SourceURI:    sourceURI,
			UDP:          true,
		},
	}
}
