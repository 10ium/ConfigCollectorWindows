package probe

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

type ipapiResponse struct {
	Company struct {
		AbuseScore string `json:"abuse_score"`
		Type       string `json:"type"` // hosting, business, residential
	} `json:"company"`
	Datacenter bool `json:"is_datacenter"`
	VPN        bool `json:"is_vpn"`
	Tor        bool `json:"is_tor"`
}

// ProbeFraudScore executes Test 11: checks IP risk/fraud score (0 clean to 100 high risk).
func ProbeFraudScore(ctx context.Context, client *http.Client, exitIP string, node *model.Node) error {
	if exitIP == "" {
		node.Result.FraudScore = 50
		return nil
	}

	url := fmt.Sprintf("https://ipapi.is/json/%s", exitIP)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		node.Result.FraudScore = 50
		return err
	}
	req.Header.Set("User-Agent", "curl/7.88.1")

	resp, err := client.Do(req)
	if err != nil {
		// Fallback score if endpoint unreachable
		node.Result.FraudScore = 30
		return nil
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 16384))
	if err != nil {
		node.Result.FraudScore = 30
		return nil
	}

	var data ipapiResponse
	if err := json.Unmarshal(bodyBytes, &data); err != nil {
		node.Result.FraudScore = 30
		return nil
	}

	// Calculate baseline fraud score
	score := 10
	if data.Datacenter {
		score += 30
	}
	if data.VPN {
		score += 25
	}
	if data.Tor {
		score += 35
	}
	if strings.ToLower(data.Company.Type) == "hosting" {
		score += 15
	}

	if score > 100 {
		score = 100
	}
	node.Result.FraudScore = score
	return nil
}
