package collect

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
	"github.com/10ium/freedom-config-collector/engine/internal/parse"
)

// SubscriptionCollector downloads and extracts configs from subscription URLs.
type SubscriptionCollector struct {
	Client *http.Client
}

// NormalizeSubscriptionURL converts GitHub blob/web URLs to direct raw.githubusercontent.com URLs.
func NormalizeSubscriptionURL(subURL string) string {
	trimmed := strings.TrimSpace(subURL)
	if strings.HasPrefix(trimmed, "https://github.com/") || strings.HasPrefix(trimmed, "http://github.com/") {
		if strings.Contains(trimmed, "/blob/") {
			normalized := strings.Replace(trimmed, "github.com/", "raw.githubusercontent.com/", 1)
			normalized = strings.Replace(normalized, "/blob/", "/", 1)
			return normalized
		}
	}
	return trimmed
}

// FetchSubscription downloads a subscription URL and extracts nodes.
func (sc *SubscriptionCollector) FetchSubscription(ctx context.Context, subURL string) ([]*model.Node, error) {
	subURL = NormalizeSubscriptionURL(subURL)
	req, err := http.NewRequestWithContext(ctx, "GET", subURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "v2rayN/6.23 ClashMeta/1.18.0")

	resp, err := sc.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024)) // 10MB cap
	if err != nil {
		return nil, err
	}

	nodes, _ := parse.ExtractNodes(string(bodyBytes), "subscription", subURL)
	return nodes, nil
}

// ScanLocalFolder recursively scans a folder for text files and extracts configs.
func ScanLocalFolder(rootPath string, recursive bool, maxFileSizeBytes int64) ([]*model.Node, error) {
	var allNodes []*model.Node

	err := filepath.Walk(rootPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			if !recursive && path != rootPath {
				return filepath.SkipDir
			}
			return nil
		}

		// Only process text files
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".txt" && ext != ".yaml" && ext != ".yml" && ext != ".json" && ext != ".conf" {
			return nil
		}

		if maxFileSizeBytes > 0 && info.Size() > maxFileSizeBytes {
			return nil
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}

		nodes, _ := parse.ExtractNodes(string(data), "local_file", path)
		allNodes = append(allNodes, nodes...)
		return nil
	})

	return allNodes, err
}
