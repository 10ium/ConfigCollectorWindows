package probe

import (
	"context"
	"math"
	"net/http"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ProbeStability executes Test 10: measures packet loss and jitter across repeated pings.
func ProbeStability(ctx context.Context, client *http.Client, pingURL string, count int, intervalMs int, node *model.Node) error {
	if count <= 1 {
		count = 4
	}
	if intervalMs <= 0 {
		intervalMs = 250
	}

	var successfulPings []float64
	failures := 0

	for i := 0; i < count; i++ {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		req, err := http.NewRequestWithContext(ctx, "GET", pingURL, nil)
		if err != nil {
			failures++
			continue
		}

		start := time.Now()
		resp, err := client.Do(req)
		dur := time.Since(start)

		if err != nil {
			failures++
		} else {
			resp.Body.Close()
			successfulPings = append(successfulPings, float64(dur.Microseconds())/1000.0)
		}

		if i < count-1 {
			time.Sleep(time.Duration(intervalMs) * time.Millisecond)
		}
	}

	// Calculate packet loss percentage
	node.Result.PacketLossPercent = (float64(failures) / float64(count)) * 100.0

	// Calculate jitter (mean absolute difference between consecutive latencies)
	if len(successfulPings) > 1 {
		var diffSum float64
		for i := 1; i < len(successfulPings); i++ {
			diffSum += math.Abs(successfulPings[i] - successfulPings[i-1])
		}
		node.Result.JitterMs = diffSum / float64(len(successfulPings)-1)
	} else if len(successfulPings) == 1 {
		node.Result.JitterMs = 0.0
	} else {
		node.Result.JitterMs = 999.0
	}

	return nil
}
