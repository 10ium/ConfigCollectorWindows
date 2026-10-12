package probe

import (
	"context"
	"net"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// Standard DNS query packet for google.com (Type A, Class IN, Transaction ID 0x1234)
var dnsQueryPacket = []byte{
	0x12, 0x34, // Transaction ID
	0x01, 0x00, // Flags: Standard query
	0x00, 0x01, // Questions: 1
	0x00, 0x00, // Answer RRs: 0
	0x00, 0x00, // Authority RRs: 0
	0x00, 0x00, // Additional RRs: 0
	// Query: google.com
	0x06, 'g', 'o', 'o', 'g', 'l', 'e',
	0x03, 'c', 'o', 'm',
	0x00,       // End of name
	0x00, 0x01, // Type: A
	0x00, 0x01, // Class: IN
}

// ProbeUDP executes Test 9: sends a lightweight DNS query packet to verify UDP transport.
func ProbeUDP(ctx context.Context, dialUDP func(ctx context.Context, network, addr string) (net.Conn, error), targetServer string, timeout time.Duration, node *model.Node) error {
	if targetServer == "" {
		targetServer = "1.1.1.1:53"
	}

	conn, err := dialUDP(ctx, "udp", targetServer)
	if err != nil {
		node.Result.UDPSupported = false
		return err
	}
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(timeout))

	if _, err := conn.Write(dnsQueryPacket); err != nil {
		node.Result.UDPSupported = false
		return err
	}

	buf := make([]byte, 512)
	n, err := conn.Read(buf)
	if err != nil || n < 12 {
		node.Result.UDPSupported = false
		return err
	}

	// Verify transaction ID matches 0x1234
	if buf[0] == 0x12 && buf[1] == 0x34 {
		node.Result.UDPSupported = true
	} else {
		node.Result.UDPSupported = false
	}

	return nil
}
