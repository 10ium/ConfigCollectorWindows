package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/10ium/freedom-config-collector/engine/internal/export"
	"github.com/10ium/freedom-config-collector/engine/internal/model"
	"github.com/10ium/freedom-config-collector/engine/internal/parse"
	"github.com/10ium/freedom-config-collector/engine/internal/score"
)

const AppVersion = "2.0.0"

func main() {
	versionFlag := flag.Bool("version", false, "Print version information")
	smokeFlag := flag.Bool("smoke", false, "Run an internal smoke test on synthetic fixtures")
	flag.Parse()

	if *versionFlag {
		fmt.Printf("Freedom Config Collector Engine v%s\n", AppVersion)
		os.Exit(0)
	}

	if *smokeFlag {
		runSmokeTest()
		os.Exit(0)
	}

	fmt.Printf("Freedom Config Collector Engine v%s\n", AppVersion)
	fmt.Println("Usage: ccli -smoke | -version")
}

func runSmokeTest() {
	fmt.Println("==> Running Engine Smoke Test...")

	fixture := `
vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?security=reality&sni=test.com&pbk=key&sid=123#Node1
vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?security=reality&sni=test.com&pbk=key&sid=123#DuplicateNode1
hy2://pass123@5.6.7.8:8443?sni=speed.com&insecure=1#Node2
`
	nodes, dupes := parse.ExtractNodes(fixture, "smoke", "fixture")
	fmt.Printf("Extracted: %d nodes, Duplicates removed: %d\n", len(nodes), dupes)
	if len(nodes) != 2 || dupes != 1 {
		fmt.Println("FAIL: Extraction or deduplication mismatch")
		os.Exit(1)
	}

	// Mock test results
	nodes[0].Result = model.TestResult{
		Alive:             true,
		PingMs:            85.0,
		PingMicroseconds:  85000,
		CountryCode:       "DE",
		FlagEmoji:         "🇩🇪",
		UDPSupported:      true,
		PacketLossPercent: 0.0,
		JitterMs:          3.2,
		FraudScore:        10,
	}

	nodes[1].Result = model.TestResult{
		Alive:             true,
		PingMs:            180.0,
		PingMicroseconds:  180000,
		CountryCode:       "FI",
		FlagEmoji:         "🇫🇮",
		UDPSupported:      true,
		PacketLossPercent: 5.0,
		JitterMs:          8.5,
		FraudScore:        25,
	}

	weights := score.DefaultWeights()
	for _, n := range nodes {
		n.Result.Score = score.CalculateScore(n, weights)
	}

	score.SortByScore(nodes)
	fmt.Printf("Rank 1: %s (Score: %.5f)\n", nodes[0].FormattedName(""), nodes[0].Result.Score)
	fmt.Printf("Rank 2: %s (Score: %.5f)\n", nodes[1].FormattedName(""), nodes[1].Result.Score)

	// Verify Clash YAML export
	yamlOut, err := export.GenerateClashProviderYAML(nodes, "")
	if err != nil {
		fmt.Printf("FAIL: Clash export error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Clash YAML export verified:")
	fmt.Println(yamlOut[:120] + "...")

	fmt.Println("==> ALL SMOKE TESTS PASSED!")
}
