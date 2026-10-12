package parse

import (
	"strings"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

var (
	allSchemesRegex = BuildSchemesRegex()
)

// ExtractNodes parses any raw text, subscription payload, or file content.
// It automatically detects encrypted containers (.ehi, .nm, .hat, .dark, .ssc, .npv),
// structured configs (Clash YAML, Sing-box JSON, WireGuard conf), and all 43 URI protocols.
func ExtractNodes(rawContent, sourceType, sourceURI string) ([]*model.Node, int) {
	// Step 1: Detect container or structured formats
	trimmed := strings.TrimSpace(rawContent)

	// A. Clash/Mihomo YAML
	if strings.Contains(trimmed, "proxies:") {
		if yamlNodes := ParseMihomoYaml(trimmed, sourceURI); len(yamlNodes) > 0 {
			return deduplicateNodes(yamlNodes)
		}
	}

	// B. Sing-box JSON
	if strings.Contains(trimmed, `"outbounds"`) {
		if sbNodes := ParseSingboxJSON(trimmed, sourceURI); len(sbNodes) > 0 {
			return deduplicateNodes(sbNodes)
		}
	}

	// C. WireGuard .conf
	if strings.Contains(trimmed, "[Interface]") && strings.Contains(trimmed, "[Peer]") {
		if wgNodes := ParseWireGuardConf(trimmed, sourceURI); len(wgNodes) > 0 {
			return deduplicateNodes(wgNodes)
		}
	}

	// D. NetMod Syna (.nm or nm-*://)
	if strings.HasPrefix(trimmed, "nm-") || strings.HasSuffix(strings.ToLower(sourceURI), ".nm") {
		if nmNodes, err := DecryptNetMod(trimmed, sourceURI); err == nil && len(nmNodes) > 0 {
			return deduplicateNodes(nmNodes)
		}
	}

	// E. HA Tunnel Plus (.hat)
	if strings.HasSuffix(strings.ToLower(sourceURI), ".hat") {
		if hatNodes, err := DecryptHat(trimmed, sourceURI); err == nil && len(hatNodes) > 0 {
			return deduplicateNodes(hatNodes)
		}
	}

	// F. DarkTunnel (.dark or darktunnel://)
	if strings.HasPrefix(trimmed, "darktunnel://") || strings.HasSuffix(strings.ToLower(sourceURI), ".dark") {
		if dtNodes, err := DecryptDarkTunnel(trimmed, sourceURI); err == nil && len(dtNodes) > 0 {
			return deduplicateNodes(dtNodes)
		}
	}

	// G. SSH Custom (.ssc or ssc://)
	if strings.HasPrefix(trimmed, "ssc://") || strings.HasSuffix(strings.ToLower(sourceURI), ".ssc") {
		if sscNodes, err := DecryptSSHCustom(trimmed, sourceURI); err == nil && len(sscNodes) > 0 {
			return deduplicateNodes(sscNodes)
		}
	}

	// H. HTTP Injector (.ehi)
	if strings.HasSuffix(strings.ToLower(sourceURI), ".ehi") {
		if ehiNodes, err := DecryptEHI([]byte(rawContent), sourceURI); err == nil && len(ehiNodes) > 0 {
			return deduplicateNodes(ehiNodes)
		}
	}

	// I. NapsternetV (.npv, .npv4, .npvt)
	if strings.HasSuffix(strings.ToLower(sourceURI), ".npv") || strings.HasSuffix(strings.ToLower(sourceURI), ".npv4") || strings.HasSuffix(strings.ToLower(sourceURI), ".npvt") {
		if npvNodes, err := DecryptNapsternetV(trimmed, sourceURI); err == nil && len(npvNodes) > 0 {
			return deduplicateNodes(npvNodes)
		}
	}

	// J. OpenVPN (.ovpn, or containing <ca> and client dev tun)
	if strings.HasSuffix(strings.ToLower(sourceURI), ".ovpn") || strings.Contains(trimmed, "<ca>") || (strings.Contains(trimmed, "client") && strings.Contains(trimmed, "dev tun")) {
		if ovpnNodes := ParseOpenVPN(trimmed, sourceURI); len(ovpnNodes) > 0 {
			return deduplicateNodes(ovpnNodes)
		}
	}

	// Step 2: Clean control characters and HTML entities
	cleaned := CleanText(rawContent)

	// Step 3: Unwrap potential base64 subscriptions
	unwrapped := DecodeBase64MultiLayer(cleaned)

	// Step 4: Extract all 43 protocol URI schemes
	matches := allSchemesRegex.FindAllString(unwrapped, -1)
	if len(matches) == 0 && unwrapped != cleaned {
		matches = allSchemesRegex.FindAllString(cleaned, -1)
	}

	var rawNodes []*model.Node
	for _, rawLink := range matches {
		rawLink = strings.TrimSpace(rawLink)
		node, err := parseSingleURI(rawLink)
		if err != nil || node == nil {
			continue
		}
		node.SourceType = sourceType
		node.SourceURI = sourceURI
		node.Discovered = time.Now()
		rawNodes = append(rawNodes, node)
	}

	return deduplicateNodes(rawNodes)
}

func parseSingleURI(rawURI string) (*model.Node, error) {
	low := strings.ToLower(rawURI)
	switch {
	case strings.HasPrefix(low, "vless://") || strings.HasPrefix(low, "trojan://"):
		return ParseVlessOrTrojan(rawURI)
	case strings.HasPrefix(low, "vmess://"):
		return ParseVmess(rawURI)
	case strings.HasPrefix(low, "hysteria2://") || strings.HasPrefix(low, "hy2://") || strings.HasPrefix(low, "hysteria://"):
		return ParseHysteria(rawURI)
	case strings.HasPrefix(low, "tuic://"):
		return ParseTuic(rawURI)
	case strings.HasPrefix(low, "ss://"):
		return ParseShadowsocks(rawURI)
	case strings.HasPrefix(low, "tg://"):
		return ParseTelegramProxy(rawURI)
	case strings.HasPrefix(low, "openvpn://"):
		return ParseOpenVPNURI(rawURI)
	default:
		// Extended protocols: snell, shadowtls, anytls, ssh, masque, ssr, dnstt, slipnet, etc.
		return ParseGenericURI(rawURI)
	}
}

func deduplicateNodes(nodes []*model.Node) ([]*model.Node, int) {
	seen := make(map[string]bool)
	var unique []*model.Node
	dupes := 0

	for _, n := range nodes {
		fp := n.TechnicalFingerprint()
		if seen[fp] {
			dupes++
			continue
		}
		seen[fp] = true
		unique = append(unique, n)
	}
	return unique, dupes
}
