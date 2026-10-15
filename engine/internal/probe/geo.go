package probe

import (
	"bufio"
	"context"
	"io"
	"net/http"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// CountryCodeToFlagEmoji converts an ISO 3166-1 alpha-2 code into a Unicode flag emoji.
func CountryCodeToFlagEmoji(countryCode string) string {
	cc := strings.ToUpper(strings.TrimSpace(countryCode))
	if len(cc) != 2 {
		return "🌐"
	}
	r1 := rune(cc[0])
	r2 := rune(cc[1])
	if r1 < 'A' || r1 > 'Z' || r2 < 'A' || r2 > 'Z' {
		return "🌐"
	}
	// Regional indicator symbols start at 0x1F1E6 for 'A'
	return string([]rune{0x1F1E6 + (r1 - 'A'), 0x1F1E6 + (r2 - 'A')})
}

// CheckExitGeo queries an endpoint (like cloudflare.com/cdn-cgi/trace) through the proxy
// to detect the true outbound IP and country code.
func CheckExitGeo(ctx context.Context, client *http.Client, traceURL string, node *model.Node) error {
	if traceURL == "" {
		traceURL = "https://cloudflare.com/cdn-cgi/trace"
	}

	req, err := http.NewRequestWithContext(ctx, "GET", traceURL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "curl/7.88.1")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	scanner := bufio.NewScanner(io.LimitReader(resp.Body, 8192))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ip=") {
			node.Result.ExitIP = strings.TrimPrefix(line, "ip=")
		} else if strings.HasPrefix(line, "loc=") {
			loc := strings.TrimPrefix(line, "loc=")
			node.Result.CountryCode = loc
			node.Result.FlagEmoji = CountryCodeToFlagEmoji(loc)
		}
	}

	if node.Result.CountryCode == "" {
		node.Result.CountryCode = "UN"
		node.Result.FlagEmoji = "🌐"
	}
	return nil
}
