package collect

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
	"github.com/10ium/freedom-config-collector/engine/internal/parse"
)

var (
	beforeRegex = regexp.MustCompile(`href="[^"]*before=(\d+)"`)
)

// TelegramCollector fetches configs from public telegram channels (t.me/s/...)
type TelegramCollector struct {
	Client       *http.Client
	Channels     []string
	MaxPages     int
	LookbackDays int
	DelayMs      int
}

// NewHTTPClient creates an HTTP client supporting direct, system proxy, or custom HTTP/SOCKS5.
func NewHTTPClient(proxyType, proxyHost string, proxyPort int, timeoutSec int, ignoreSSL bool) *http.Client {
	transport := &http.Transport{
		MaxIdleConns:        100,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression: false,
	}

	if proxyType == "http" || proxyType == "socks5" {
		proxyURLStr := fmt.Sprintf("%s://%s:%d", proxyType, proxyHost, proxyPort)
		if u, err := url.Parse(proxyURLStr); err == nil {
			transport.Proxy = http.ProxyURL(u)
		}
	} else if proxyType == "system" {
		transport.Proxy = http.ProxyFromEnvironment
	}

	return &http.Client{
		Transport: transport,
		Timeout:   time.Duration(timeoutSec) * time.Second,
	}
}

// FetchChannelScrapes scrapes a single telegram channel with pagination up to maxPages.
func (tc *TelegramCollector) FetchChannelScrapes(ctx context.Context, channel string) ([]*model.Node, error) {
	chanName := strings.TrimPrefix(strings.TrimSpace(channel), "@")
	if strings.Contains(chanName, "t.me/") {
		parts := strings.Split(chanName, "t.me/")
		if len(parts) > 1 {
			chanName = strings.Trim(parts[1], "/")
		}
	}
	if chanName == "" {
		return nil, nil
	}

	var allNodes []*model.Node
	baseURL := fmt.Sprintf("https://t.me/s/%s", chanName)
	currentURL := baseURL

	for page := 1; page <= tc.MaxPages; page++ {
		select {
		case <-ctx.Done():
			return allNodes, ctx.Err()
		default:
		}

		req, err := http.NewRequestWithContext(ctx, "GET", currentURL, nil)
		if err != nil {
			break
		}
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

		resp, err := tc.Client.Do(req)
		if err != nil {
			break
		}

		bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 5*1024*1024))
		resp.Body.Close()
		if err != nil {
			break
		}

		htmlContent := string(bodyBytes)
		nodes, _ := parse.ExtractNodes(htmlContent, "telegram", "@"+chanName)
		allNodes = append(allNodes, nodes...)

		// Find pagination link for older messages (?before=XYZ)
		matches := beforeRegex.FindStringSubmatch(htmlContent)
		if len(matches) > 1 {
			beforeID, _ := strconv.Atoi(matches[1])
			if beforeID > 0 {
				currentURL = fmt.Sprintf("https://t.me/s/%s?before=%d", chanName, beforeID)
			} else {
				break
			}
		} else {
			break
		}

		if tc.DelayMs > 0 {
			time.Sleep(time.Duration(tc.DelayMs) * time.Millisecond)
		}
	}

	return allNodes, nil
}
