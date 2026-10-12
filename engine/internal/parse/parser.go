package parse

import (
	"regexp"
	"strings"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

var (
	linkRegex = regexp.MustCompile(`(?i)(vless|vmess|trojan|hysteria2|hy2|tuic|ss|tg)://[^\s<>"'\r\n]+`)
)

// ExtractNodes parses a raw text body, automatically unwraps Base64 layers, extracts
// all valid proxy configurations, and removes duplicates using technical fingerprints.
func ExtractNodes(rawContent, sourceType, sourceURI string) ([]*model.Node, int) {
	// Step 1: Clean control characters and HTML entities
	cleaned := CleanText(rawContent)

	// Step 2: Unwrap potential base64 subscriptions
	unwrapped := DecodeBase64MultiLayer(cleaned)

	// Step 3: Match all link candidates
	matches := linkRegex.FindAllString(unwrapped, -1)
	if len(matches) == 0 && unwrapped != cleaned {
		// Fallback check on original cleaned text
		matches = linkRegex.FindAllString(cleaned, -1)
	}

	seenFingerprints := make(map[string]bool)
	var nodes []*model.Node
	duplicatesCount := 0

	for _, rawLink := range matches {
		rawLink = strings.TrimSpace(rawLink)
		node, err := parseSingleURI(rawLink)
		if err != nil || node == nil {
			continue
		}

		node.SourceType = sourceType
		node.SourceURI = sourceURI
		node.Discovered = time.Now()

		fp := node.TechnicalFingerprint()
		if seenFingerprints[fp] {
			duplicatesCount++
			continue
		}

		seenFingerprints[fp] = true
		nodes = append(nodes, node)
	}

	return nodes, duplicatesCount
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
	default:
		return nil, nil
	}
}
