package parse

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

var (
	tagRegex       = regexp.MustCompile(`(?s)<([a-zA-Z0-9_\-]+)>\s*(.*?)\s*</\1>`)
	remoteRegex    = regexp.MustCompile(`(?i)^\s*remote\s+([^\s]+)\s+([0-9]+)(?:\s+([a-zA-Z0-9]+))?`)
	protoRegex     = regexp.MustCompile(`(?i)^\s*proto\s+([a-zA-Z0-9]+)`)
	cipherRegex    = regexp.MustCompile(`(?i)^\s*(?:cipher|data-ciphers)\s+([^\s]+)`)
	authRegex      = regexp.MustCompile(`(?i)^\s*auth\s+([^\s]+)`)
	keyDirRegex    = regexp.MustCompile(`(?i)^\s*key-direction\s+([0-9]+)`)
)

// ParseOpenVPN parses raw .ovpn configuration text into model.Node objects.
func ParseOpenVPN(content, sourceURI string) []*model.Node {
	tags := make(map[string]string)
	for _, match := range tagRegex.FindAllStringSubmatch(content, -1) {
		if len(match) == 3 {
			tagName := strings.ToLower(match[1])
			tagContent := strings.TrimSpace(match[2])
			tags[tagName] = tagContent
		}
	}

	// Extract lines for remote, proto, cipher, auth
	lines := strings.Split(content, "\n")
	var remotes [][3]string // host, port, proto
	defaultProto := "udp"
	cipher := ""
	auth := ""
	keyDirection := ""

	for _, line := range lines {
		l := strings.TrimSpace(line)
		if strings.HasPrefix(l, "#") || strings.HasPrefix(l, ";") || l == "" {
			continue
		}

		if m := remoteRegex.FindStringSubmatch(l); len(m) >= 3 {
			p := defaultProto
			if len(m) >= 4 && m[3] != "" {
				p = strings.ToLower(m[3])
			}
			remotes = append(remotes, [3]string{m[1], m[2], p})
		} else if m := protoRegex.FindStringSubmatch(l); len(m) >= 2 {
			defaultProto = strings.ToLower(m[1])
			if strings.Contains(defaultProto, "tcp") {
				defaultProto = "tcp"
			} else {
				defaultProto = "udp"
			}
		} else if m := cipherRegex.FindStringSubmatch(l); len(m) >= 2 {
			cipher = m[1]
		} else if m := authRegex.FindStringSubmatch(l); len(m) >= 2 {
			auth = m[1]
		} else if m := keyDirRegex.FindStringSubmatch(l); len(m) >= 2 {
			keyDirection = m[1]
		}
	}

	// Credentials
	authUser := ""
	authPass := ""
	if creds, ok := tags["auth-user-pass"]; ok && creds != "" {
		credLines := strings.Split(creds, "\n")
		if len(credLines) >= 1 {
			authUser = strings.TrimSpace(credLines[0])
		}
		if len(credLines) >= 2 {
			authPass = strings.TrimSpace(credLines[1])
		}
	}

	var nodes []*model.Node
	for idx, rem := range remotes {
		portNum, err := strconv.Atoi(rem[1])
		if err != nil || portNum <= 0 || portNum > 65535 {
			continue
		}

		proto := rem[2]
		if proto == "" {
			proto = defaultProto
		}

		name := fmt.Sprintf("OpenVPN-%s:%d", rem[0], portNum)
		if idx > 0 {
			name = fmt.Sprintf("OpenVPN-%s:%d-%d", rem[0], portNum, idx+1)
		}

		node := &model.Node{
			Protocol:     "openvpn",
			Name:         name,
			Server:       rem[0],
			Port:         portNum,
			Proto:        proto,
			AuthUser:     authUser,
			AuthPass:     authPass,
			CA:           tags["ca"],
			Cert:         tags["cert"],
			Key:          tags["key"],
			TLSAuth:      tags["tls-auth"],
			TLSCrypt:     tags["tls-crypt"],
			TLSCryptV2:   tags["tls-crypt-v2"],
			KeyDirection: keyDirection,
			Cipher:       cipher,
			OpenVPNAuth:  auth,
			SourceType:   "local_file",
			SourceURI:    sourceURI,
			Discovered:   time.Now(),
		}

		node.ID = node.TechnicalFingerprint()
		nodes = append(nodes, node)
	}

	return nodes
}

// ParseOpenVPNURI handles openvpn://base64(ovpn_content) or standard URL format
func ParseOpenVPNURI(rawURI string) (*model.Node, error) {
	if strings.HasPrefix(rawURI, "openvpn://") {
		payload := strings.TrimPrefix(rawURI, "openvpn://")
		if decoded, err := base64.StdEncoding.DecodeString(payload); err == nil {
			nodes := ParseOpenVPN(string(decoded), rawURI)
			if len(nodes) > 0 {
				return nodes[0], nil
			}
		}

		// Or URL style: openvpn://user:pass@host:port?proto=udp&cipher=...
		u, err := url.Parse(rawURI)
		if err != nil {
			return nil, err
		}
		port, _ := strconv.Atoi(u.Port())
		if port == 0 {
			port = 1194
		}
		user := u.User.Username()
		pass, _ := u.User.Password()
		proto := u.Query().Get("proto")
		if proto == "" {
			proto = "udp"
		}

		node := &model.Node{
			Protocol: "openvpn",
			Name:     u.Fragment,
			Server:   u.Hostname(),
			Port:     port,
			Proto:    proto,
			AuthUser: user,
			AuthPass: pass,
			Cipher:   u.Query().Get("cipher"),
		}
		node.ID = node.TechnicalFingerprint()
		return node, nil
	}
	return nil, fmt.Errorf("invalid openvpn URI")
}
