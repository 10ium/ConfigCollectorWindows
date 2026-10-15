package parse

import (
	"encoding/base64"
	"html"
	"regexp"
	"strings"
)

var (
	// Regex matching control characters (preserving \t \n \r), non-printable characters, zero-width spaces, and replacement chars.
	controlCharRegex = regexp.MustCompile(`[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\x{200B}-\x{200D}\x{FEFF}\x{FFFD}]`)
)

// CleanText removes invisible unicode artifacts and decodes HTML entities.
func CleanText(raw string) string {
	decoded := html.UnescapeString(raw)
	cleaned := controlCharRegex.ReplaceAllString(decoded, "")
	return strings.TrimSpace(cleaned)
}

// DecodeBase64MultiLayer attempts to decode standard, URL-safe, and multi-layer Base64 data.
func DecodeBase64MultiLayer(input string) string {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return ""
	}

	// If it already clearly contains protocol links, no base64 unwrap needed
	if strings.Contains(trimmed, "://") && !strings.HasPrefix(trimmed, "vmess://") {
		return trimmed
	}

	// Remove all internal whitespace
	cleanB64 := strings.Map(func(r rune) rune {
		if r == ' ' || r == '\n' || r == '\r' || r == '\t' {
			return -1
		}
		return r
	}, trimmed)

	// Attempt up to 3 layers of base64 unwrap
	current := cleanB64
	for i := 0; i < 3; i++ {
		decoded, ok := tryDecodeBase64(current)
		if !ok || len(decoded) == 0 {
			break
		}
		// If decoded string has protocol links, we've found the payload!
		if strings.Contains(decoded, "://") || strings.Contains(decoded, "proxies:") {
			return decoded
		}
		current = strings.TrimSpace(decoded)
	}

	return input
}

func tryDecodeBase64(data string) (string, bool) {
	// Standard padding
	padLen := (4 - (len(data) % 4)) % 4
	padded := data + strings.Repeat("=", padLen)

	// Try standard base64
	if b, err := base64.StdEncoding.DecodeString(padded); err == nil {
		return string(b), true
	}

	// Try URL-safe base64
	if b, err := base64.URLEncoding.DecodeString(padded); err == nil {
		return string(b), true
	}

	// Try raw standard (unpadded)
	if b, err := base64.RawStdEncoding.DecodeString(data); err == nil {
		return string(b), true
	}

	// Try raw URL-safe (unpadded)
	if b, err := base64.RawURLEncoding.DecodeString(data); err == nil {
		return string(b), true
	}

	return "", false
}
