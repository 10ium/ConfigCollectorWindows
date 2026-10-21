package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

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
soar://eyJwcm9maWxlIjp7ImlkIjoiNDRjMjc0YTMzNTM1MGZhYzljMjg0ZWNhOGVhMzkyNzYiLCJuYW1lIjoiV2hpdGVETlMgUHVibGljIiwicmVzb2x2ZXJzIjpbIjEuMS4xLjEiLCI4LjguOC44Il0sInNlcnZlciI6eyJkb21haW4iOiJpdGJoaml6dmd1aDJ6aGJpajNmaTVpLnNvYXIud2hpdGVkbnMuZG93bmxvYWQiLCJwdWJsaWNfa2V5IjoiR1daa2NSVVErUHhqMnEydXRKZllEV2cwR2dOR3AybmtVMmN5UE8ySk1UMD0ifSwic29hclNldHRpbmdzIjp7InRyYW5zcG9ydCI6ImF1dG8ifX0sInNjaGVtYSI6IndoaXRlZG5zLnByb2ZpbGUiLCJ2ZXJzaW9uIjoxfQ==
cottendns://eyJwcm9maWxlIjp7ImVuZ2luZSI6ImNvdHRlbmRucyIsImlkIjoiNDRjMjc0YTMzNTM1MGZhYzljMjg0ZWNhOGVhMzkyNzY6Y290dGVuIiwibmFtZSI6IldoaXRlRE5TIFB1YmxpYyDCtyBDb3R0ZW4iLCJyZXNvbHZlcnMiOlsiMS4xLjEuMSIsIjguOC44LjgiXSwic2VydmVyIjp7ImRvbWFpbiI6ImNvdC5pdGJoaml6dmd1aDJ6aGJpajNmaTVpLnNvYXIud2hpdGVkbnMuZG93bmxvYWQiLCJlbmNyeXB0aW9uX2tleSI6IjllMjhlZWNhNDk2MDFhNGYwNGM0MDg2M2RkODM4NjQ3OWI2YWYzNzJiMTFiODc3MzlhYjI5YWIyYTQ3NDEyMzkiLCJlbmNyeXB0aW9uX21ldGhvZCI6NX19LCJzY2hlbWEiOiJ3aGl0ZWRucy5wcm9maWxlIiwidmVyc2lvbiI6MX0=
tg://proxy?server=9.10.11.12&port=443&secret=dd00112233445566778899aabbccddeeff
`
	nodes, dupes := parse.ExtractNodes(fixture, "smoke", "fixture")
	fmt.Printf("Extracted: %d nodes, Duplicates removed: %d\n", len(nodes), dupes)
	if len(nodes) != 5 || dupes != 1 {
		fmt.Printf("FAIL: Extraction or deduplication mismatch, got %d nodes\n", len(nodes))
		os.Exit(1)
	}

	// Verify categories
	for _, n := range nodes {
		cat := n.GetCategory()
		fmt.Printf("Protocol: %-10s | Category: %-12s | Name: %s\n", n.Protocol, cat, n.Name)
		if strings.HasPrefix(n.Protocol, "vless") || strings.HasPrefix(n.Protocol, "hy2") {
			if cat != "mihomo" {
				fmt.Printf("FAIL: expected mihomo category for %s, got %s\n", n.Protocol, cat)
				os.Exit(1)
			}
		}
		if n.Protocol == "soar" || n.Protocol == "cottendns" {
			if cat != "dns_tunnel" || !n.IsDNSTunnel {
				fmt.Printf("FAIL: expected dns_tunnel category for %s, got %s\n", n.Protocol, cat)
				os.Exit(1)
			}
		}
		if n.Protocol == "mtproto" || n.Protocol == "tg" || n.Protocol == "tg-socks" {
			if cat != "telegram" || !n.IsTelegramProxy {
				fmt.Printf("FAIL: expected telegram category for %s, got %s\n", n.Protocol, cat)
				os.Exit(1)
			}
		}
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
