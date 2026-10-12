package score

import (
	"testing"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

func TestScoringAndTieBreaker(t *testing.T) {
	weights := DefaultWeights()

	// Node 1: Fast, stable, clean
	n1 := &model.Node{
		Protocol: "vless",
		Server:   "1.1.1.1",
		Port:     443,
		UUID:     "uuid-1",
		Result: model.TestResult{
			Alive:             true,
			PingMs:            65.0,
			PingMicroseconds:  65000,
			UDPSupported:      true,
			PacketLossPercent: 0.0,
			JitterMs:          2.5,
			FraudScore:        5,
		},
	}

	// Node 2: Same server/stats as Node 1 but different UUID
	n2 := &model.Node{
		Protocol: "vless",
		Server:   "1.1.1.1",
		Port:     443,
		UUID:     "uuid-2",
		Result: model.TestResult{
			Alive:             true,
			PingMs:            65.0,
			PingMicroseconds:  65000,
			UDPSupported:      true,
			PacketLossPercent: 0.0,
			JitterMs:          2.5,
			FraudScore:        5,
		},
	}

	// Node 3: Higher ping (350ms)
	n3 := &model.Node{
		Protocol: "vless",
		Server:   "2.2.2.2",
		Port:     443,
		UUID:     "uuid-3",
		Result: model.TestResult{
			Alive:             true,
			PingMs:            350.0,
			PingMicroseconds:  350000,
			UDPSupported:      true,
			PacketLossPercent: 0.0,
			JitterMs:          15.0,
			FraudScore:        10,
		},
	}

	score1 := CalculateScore(n1, weights)
	score2 := CalculateScore(n2, weights)
	score3 := CalculateScore(n3, weights)

	n1.Result.Score = score1
	n2.Result.Score = score2
	n3.Result.Score = score3

	t.Logf("Node 1 Score: %.5f", score1)
	t.Logf("Node 2 Score: %.5f", score2)
	t.Logf("Node 3 Score: %.5f", score3)

	if score1 <= score3 {
		t.Errorf("Node 1 should score higher than Node 3, got %.5f vs %.5f", score1, score3)
	}

	// Crucial check: score1 and score2 must NOT be identical due to the tie-breaker
	if score1 == score2 {
		t.Errorf("Expected tie-breaker to differentiate Node 1 and Node 2, but both got %.5f", score1)
	}

	nodes := []*model.Node{n3, n2, n1}
	SortByScore(nodes)
	if nodes[2] != n3 {
		t.Errorf("Expected n3 to be ranked last, got %v", nodes[2])
	}
}
