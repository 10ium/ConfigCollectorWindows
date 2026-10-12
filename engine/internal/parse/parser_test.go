package parse

import (
	"testing"
)

func TestExtractNodes(t *testing.T) {
	sampleText := `
Here are some free configs:
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@1.2.3.4:443?security=reality&sni=yahoo.com&pbk=xyz123&sid=1234&type=tcp&fp=chrome#US-Reality-1

And a duplicate with a different name:
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@1.2.3.4:443?security=reality&sni=yahoo.com&pbk=xyz123&sid=1234&type=tcp&fp=chrome#DifferentName

And Hysteria2:
hy2://supersecret@5.6.7.8:8443?sni=speed.cloudflare.com&insecure=1#DE-Hy2

And Shadowsocks:
ss://YWVzLTEyOC1nY206cGFzc3dvcmQ=@9.10.11.12:8388#FI-SS
`

	nodes, dupes := ExtractNodes(sampleText, "telegram", "@test_channel")

	if len(nodes) != 3 {
		t.Fatalf("Expected 3 unique nodes, got %d", len(nodes))
	}
	if dupes != 1 {
		t.Errorf("Expected 1 duplicate, got %d", dupes)
	}

	// Verify Node 1
	n1 := nodes[0]
	if n1.Protocol != "vless" || n1.Server != "1.2.3.4" || n1.Security != "reality" {
		t.Errorf("Unexpected Node 1: %+v", n1)
	}

	// Verify Node 2 (Hy2)
	n2 := nodes[1]
	if n2.Protocol != "hysteria2" || n2.Server != "5.6.7.8" || n2.Password != "supersecret" {
		t.Errorf("Unexpected Node 2: %+v", n2)
	}

	// Verify Node 3 (SS)
	n3 := nodes[2]
	if n3.Protocol != "ss" || n3.Server != "9.10.11.12" || n3.Method != "aes-128-gcm" {
		t.Errorf("Unexpected Node 3: %+v", n3)
	}
}
