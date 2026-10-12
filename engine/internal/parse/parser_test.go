package parse

import (
	"testing"
)

func TestExtractExtendedNodes(t *testing.T) {
	sampleText := `
Here are mixed links:
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@1.2.3.4:443?security=reality&sni=yahoo.com&pbk=xyz123&sid=1234&type=tcp&fp=chrome#US-Reality-1
snell://testpsk@10.0.0.1:1443?version=4&obfs=http#SnellNode
shadowtls://shadowpass@10.0.0.2:2443?sni=speed.cloudflare.com&version=3#ShadowTLSNode
anytls://anypass@10.0.0.3:3443?sni=apple.com#AnyTLSNode
ssh://root:secret@10.0.0.4:22#SSHNode
dnstt://dnstt-server:53?pubkey=abc123pub&domain=t.me#DNSTTNode
masque://masquekey@10.0.0.5:443?sni=cloudflare.com&transport=h2#MasqueNode
`

	nodes, dupes := ExtractNodes(sampleText, "mixed", "test")
	if len(nodes) < 7 {
		t.Fatalf("Expected at least 7 nodes, got %d (dupes: %d)", len(nodes), dupes)
	}

	protocols := make(map[string]bool)
	for _, n := range nodes {
		protocols[n.Protocol] = true
	}

	expectedProtos := []string{"vless", "snell", "shadowtls", "anytls", "ssh", "dnstt", "masque"}
	for _, p := range expectedProtos {
		if !protocols[p] {
			t.Errorf("Expected protocol %s to be extracted", p)
		}
	}
}

func TestClashYamlExtraction(t *testing.T) {
	clashYaml := `
proxies:
  - name: "Yaml-Vless"
    type: vless
    server: 1.1.1.1
    port: 443
    uuid: my-uuid
    tls: true
    servername: google.com
  - name: "Yaml-Trojan"
    type: trojan
    server: 2.2.2.2
    port: 443
    password: my-pass
`

	nodes, dupes := ExtractNodes(clashYaml, "clash", "sub.yaml")
	if len(nodes) != 2 {
		t.Fatalf("Expected 2 nodes from YAML, got %d (dupes: %d)", len(nodes), dupes)
	}
	if nodes[0].Protocol != "vless" || nodes[1].Protocol != "trojan" {
		t.Errorf("Unexpected nodes: %+v, %+v", nodes[0], nodes[1])
	}
}

func TestSingboxJsonExtraction(t *testing.T) {
	sbJSON := `
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "SB-Vless",
      "server": "3.3.3.3",
      "server_port": 443,
      "uuid": "sb-uuid"
    },
    {
      "type": "hysteria2",
      "tag": "SB-Hy2",
      "server": "4.4.4.4",
      "server_port": 8443,
      "password": "sb-pass"
    }
  ]
}
`

	nodes, dupes := ExtractNodes(sbJSON, "singbox", "sub.json")
	if len(nodes) != 2 {
		t.Fatalf("Expected 2 nodes from Sing-box JSON, got %d (dupes: %d)", len(nodes), dupes)
	}
	if nodes[0].Protocol != "vless" || nodes[1].Protocol != "hysteria2" {
		t.Errorf("Unexpected nodes: %+v, %+v", nodes[0], nodes[1])
	}
}
