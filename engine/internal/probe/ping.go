package probe

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ProbePing executes Test 1: measures HTTP RTT round-trip time in milliseconds.
func ProbePing(ctx context.Context, client *http.Client, pingURL string, maxLatencyMs float64, node *model.Node) error {
	if pingURL == "" {
		pingURL = "http://cp.cloudflare.com/generate_204"
	}

	req, err := http.NewRequestWithContext(ctx, "GET", pingURL, nil)
	if err != nil {
		node.Result.Alive = false
		node.Result.Error = err.Error()
		return err
	}
	req.Header.Set("User-Agent", "FreedomConfigCollector/2.0")

	start := time.Now()
	resp, err := client.Do(req)
	duration := time.Since(start)

	if err != nil {
		node.Result.Alive = false
		node.Result.Error = err.Error()
		return err
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, io.LimitReader(resp.Body, 1024))

	pingMs := float64(duration.Microseconds()) / 1000.0
	node.Result.PingMs = pingMs
	node.Result.PingMicroseconds = duration.Microseconds()
	node.Result.Tested = true
	node.Result.TestedAt = time.Now()

	if maxLatencyMs > 0 && pingMs > maxLatencyMs {
		node.Result.Alive = false
		node.Result.Error = fmt.Sprintf("latency %.1fms exceeds limit %.1fms", pingMs, maxLatencyMs)
		return nil
	}

	node.Result.Alive = true
	return nil
}
