package score

import (
	"hash/crc32"
	"math"
	"sort"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// Weights configures the contribution of each test factor to the final composite score.
type Weights struct {
	PingWeight        float64
	StabilityWeight   float64
	UDPWeight         float64
	CleanlinessWeight float64
	SpeedWeight       float64
	SitesWeight       float64
}

// DefaultWeights returns the default weights aligned with the active default tests:
// Test 1 (Ping: 35%), Test 10 (Stability: 30%), Test 9 (UDP: 15%), Test 11 (Cleanliness: 20%).
func DefaultWeights() Weights {
	return Weights{
		PingWeight:        0.35,
		StabilityWeight:   0.30,
		UDPWeight:         0.15,
		CleanlinessWeight: 0.20,
		SpeedWeight:       0.00,
		SitesWeight:       0.00,
	}
}

// CalculateScore computes a precision floating-point quality score for a node (0.0000 - 100.0000).
func CalculateScore(node *model.Node, w Weights) float64 {
	r := &node.Result
	if !r.Alive {
		return 0.0
	}

	// 1. Non-linear Sigmoid Ping Score (0 to 100)
	// Favors lower pings (< 150ms) while heavily penalizing high pings (> 400ms).
	pingMs := math.Max(1.0, r.PingMs)
	pingScore := 100.0 / (1.0 + math.Pow(pingMs/250.0, 1.6))

	// 2. Stability & Jitter Score (0 to 100)
	lossPercent := math.Min(100.0, math.Max(0.0, r.PacketLossPercent))
	lossFactor := 1.0 - (lossPercent / 100.0)
	jitterMs := math.Max(0.0, r.JitterMs)
	jitterFactor := 100.0 / (1.0 + math.Pow(jitterMs/40.0, 1.3))
	stabilityScore := lossFactor * jitterFactor

	// 3. UDP Support Score (0 or 100)
	udpScore := 0.0
	if r.UDPSupported {
		udpScore = 100.0
	}

	// 4. IP Cleanliness & Low Fraud Score (0 to 100)
	fraud := math.Min(100.0, math.Max(0.0, float64(r.FraudScore)))
	cleanlinessScore := 100.0 - fraud

	// Calculate weighted composite
	totalWeight := w.PingWeight + w.StabilityWeight + w.UDPWeight + w.CleanlinessWeight
	if totalWeight <= 0 {
		totalWeight = 1.0
	}

	rawScore := (pingScore*w.PingWeight +
		stabilityScore*w.StabilityWeight +
		udpScore*w.UDPWeight +
		cleanlinessScore*w.CleanlinessWeight) / totalWeight

	// 5. Deterministic Tie-Breaker (prevents identical rank collisions)
	// Adds a tiny fraction (0.00001 - 0.00999) based on CRC32 of fingerprint and micro-RTT
	fp := node.TechnicalFingerprint()
	crc := crc32.ChecksumIEEE([]byte(fp))
	tieBreaker := (float64(crc%100000) / 10000000.0)
	if r.PingMicroseconds > 0 {
		tieBreaker += (1.0 / (float64(r.PingMicroseconds) + 1.0)) * 0.0009
	}

	finalScore := math.Min(100.0, rawScore+tieBreaker)
	// Round to 5 decimal places
	finalScore = math.Round(finalScore*100000.0) / 100000.0

	return finalScore
}

// SortByScore sorts a slice of nodes in-place in descending order of quality score.
func SortByScore(nodes []*model.Node) {
	sort.SliceStable(nodes, func(i, j int) bool {
		return nodes[i].Result.Score > nodes[j].Result.Score
	})
}
