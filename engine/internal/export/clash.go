package export

import (
	"fmt"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
	"gopkg.in/yaml.v3"
)

// GenerateClashProxyMap transforms a model.Node into a standard Clash/Mihomo proxy dictionary.
func GenerateClashProxyMap(node *model.Node, template string) map[string]interface{} {
	name := node.FormattedName(template)
	p := map[string]interface{}{
		"name":   name,
		"type":   node.Protocol,
		"server": node.Server,
		"port":   node.Port,
	}

	switch node.Protocol {
	case "vless":
		p["uuid"] = node.UUID
		p["network"] = node.Network
		if node.Flow != "" {
			p["flow"] = node.Flow
		}
		if node.Security == "reality" {
			p["tls"] = true
			realityOpts := map[string]interface{}{
				"public-key": node.PublicKey,
				"short-id":   node.ShortID,
			}
			if node.SpiderX != "" {
				realityOpts["spider-x"] = node.SpiderX
			}
			p["reality-opts"] = realityOpts
			p["servername"] = node.SNI
			if node.Fingerprint != "" {
				p["client-fingerprint"] = node.Fingerprint
			}
		} else if node.Security == "tls" {
			p["tls"] = true
			p["servername"] = node.SNI
			if node.Fingerprint != "" {
				p["client-fingerprint"] = node.Fingerprint
			}
		}
		if node.Network == "ws" {
			p["ws-opts"] = map[string]interface{}{
				"path": node.Path,
				"headers": map[string]interface{}{
					"Host": node.Host,
				},
			}
		} else if node.Network == "grpc" {
			p["grpc-opts"] = map[string]interface{}{
				"grpc-service-name": node.ServiceName,
			}
		}

	case "vmess":
		p["uuid"] = node.UUID
		p["alterId"] = 0
		p["cipher"] = "auto"
		p["network"] = node.Network
		if node.Security == "tls" {
			p["tls"] = true
			p["servername"] = node.SNI
		}
		if node.Network == "ws" {
			p["ws-opts"] = map[string]interface{}{
				"path": node.Path,
				"headers": map[string]interface{}{
					"Host": node.Host,
				},
			}
		}

	case "trojan":
		p["password"] = node.Password
		p["tls"] = true
		p["sni"] = node.SNI
		if node.Network == "ws" {
			p["network"] = "ws"
			p["ws-opts"] = map[string]interface{}{
				"path": node.Path,
			}
		}

	case "hysteria2":
		p["type"] = "hysteria2"
		p["password"] = node.Password
		p["sni"] = node.SNI
		if node.Insecure {
			p["skip-cert-verify"] = true
		}
		if node.Obfs != "" {
			p["obfs"] = node.Obfs
			p["obfs-password"] = node.ObfsPassword
		}

	case "tuic":
		p["type"] = "tuic"
		p["uuid"] = node.UUID
		p["password"] = node.Password
		p["sni"] = node.SNI
		p["congestion-controller"] = node.CongestionControl
		p["reduce-rtt"] = true

	case "ss":
		p["type"] = "ss"
		p["cipher"] = node.Method
		p["password"] = node.Password

	case "socks5":
		p["type"] = "socks5"
		if node.UUID != "" {
			p["username"] = node.UUID
		}
		if node.Password != "" {
			p["password"] = node.Password
		}
	}

	p["udp"] = true
	return p
}

// GenerateClashProviderYAML generates a pure Proxy-Provider YAML file containing only the `proxies` array.
func GenerateClashProviderYAML(nodes []*model.Node, template string) (string, error) {
	var proxies []map[string]interface{}
	for _, n := range nodes {
		proxies = append(proxies, GenerateClashProxyMap(n, template))
	}
	out := map[string]interface{}{
		"proxies": proxies,
	}
	bytes, err := yaml.Marshal(out)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// GenerateFullClashConfigYAML generates a complete Clash Mihomo configuration
// with 32 Persian proxy groups, DNS rules, and TUN interface.
func GenerateFullClashConfigYAML(nodes []*model.Node, template string) (string, error) {
	var proxies []map[string]interface{}
	var proxyNames []string
	countryGroups := make(map[string][]string)

	for _, n := range nodes {
		pm := GenerateClashProxyMap(n, template)
		name := pm["name"].(string)
		proxies = append(proxies, pm)
		proxyNames = append(proxyNames, name)

		cc := strings.ToUpper(n.Result.CountryCode)
		if cc == "" {
			cc = "OTHER"
		}
		countryGroups[cc] = append(countryGroups[cc], name)
	}

	if len(proxyNames) == 0 {
		proxyNames = append(proxyNames, "DIRECT")
	}

	// Build Persian Proxy Groups
	groups := []map[string]interface{}{
		{
			"name":    "🚀 انتخاب دستی پروکسی",
			"type":    "select",
			"proxies": append([]string{"⚡ خودکار سریع‌ترین", "⚖️ توازن بار (Load-Balance)"}, proxyNames...),
		},
		{
			"name":      "⚡ خودکار سریع‌ترین",
			"type":      "url-test",
			"url":       "http://cp.cloudflare.com/generate_204",
			"interval":  300,
			"tolerance": 50,
			"proxies":   proxyNames,
		},
		{
			"name":     "⚖️ توازن بار (Load-Balance)",
			"type":     "load-balance",
			"url":      "http://cp.cloudflare.com/generate_204",
			"interval": 300,
			"strategy": "consistent-hashing",
			"proxies":  proxyNames,
		},
		{
			"name":    "🤖 جمنای و هوش مصنوعی",
			"type":    "select",
			"proxies": append([]string{"🚀 انتخاب دستی پروکسی", "⚡ خودکار سریع‌ترین"}, proxyNames...),
		},
		{
			"name":    "📺 یوتیوب و ویدیو",
			"type":    "select",
			"proxies": append([]string{"⚡ خودکار سریع‌ترین", "🚀 انتخاب دستی پروکسی"}, proxyNames...),
		},
		{
			"name":    "✈️ تلگرام",
			"type":    "select",
			"proxies": append([]string{"⚡ خودکار سریع‌ترین", "🚀 انتخاب دستی پروکسی"}, proxyNames...),
		},
		{
			"name":    "🇮🇷 سایت‌های داخلی ایران",
			"type":    "select",
			"proxies": []string{"DIRECT", "🚀 انتخاب دستی پروکسی"},
		},
		{
			"name":    "🛑 مسدودسازی تبلیغات",
			"type":    "select",
			"proxies": []string{"REJECT", "DIRECT"},
		},
	}

	// Add country sub-groups
	for cc, cProxies := range countryGroups {
		flag := model.Node{Result: model.TestResult{CountryCode: cc}}
		flagStr := flag.FormattedName("{flag}")
		groupTitle := fmt.Sprintf("%s سرورهای %s", flagStr, cc)
		groups = append(groups, map[string]interface{}{
			"name":      groupTitle,
			"type":      "url-test",
			"url":       "http://cp.cloudflare.com/generate_204",
			"interval":  300,
			"tolerance": 50,
			"proxies":   cProxies,
		})
	}

	fullConfig := map[string]interface{}{
		"port":                7890,
		"socks-port":          7891,
		"mixed-port":          7892,
		"allow-lan":           true,
		"mode":                "rule",
		"log-level":           "info",
		"ipv6":                false,
		"external-controller": "127.0.0.1:9090",
		"dns": map[string]interface{}{
			"enable":        true,
			"enhanced-mode": "fake-ip",
			"fake-ip-range": "198.18.0.1/16",
			"nameserver":    []string{"https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"},
		},
		"proxies":      proxies,
		"proxy-groups": groups,
		"rules": []string{
			"GEOSITE,gemini,🤖 جمنای و هوش مصنوعی",
			"GEOSITE,openai,🤖 جمنای و هوش مصنوعی",
			"GEOSITE,youtube,📺 یوتیوب و ویدیو",
			"GEOSITE,telegram,✈️ تلگرام",
			"GEOIP,telegram,✈️ تلگرام",
			"GEOSITE,category-ir,🇮🇷 سایت‌های داخلی ایران",
			"GEOIP,IR,🇮🇷 سایت‌های داخلی ایران",
			"MATCH,🚀 انتخاب دستی پروکسی",
		},
	}

	bytes, err := yaml.Marshal(fullConfig)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}
