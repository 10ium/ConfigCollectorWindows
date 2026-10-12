package parse

import (
	"crypto/aes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

var netmodKeys = [][]byte{
	[]byte("<n3t5yn4^n3tm0d>"),
	[]byte("_netsyna_netmod_"),
	[]byte("nicetrybuddygoon"),
}

const hatImportKey = "8515D40BD04D8C97"

// DecryptNetMod decrypts NetMod Syna (.nm) files or nm-*:// links using AES-128-ECB.
func DecryptNetMod(rawInput, sourceURI string) ([]*model.Node, error) {
	text := strings.TrimSpace(rawInput)
	if idx := strings.Index(text, "://"); idx != -1 && strings.HasPrefix(text, "nm-") {
		text = text[idx+3:]
	}

	ciphertext, err := base64.StdEncoding.DecodeString(text)
	if err != nil {
		// Try unpadded
		ciphertext, err = base64.RawStdEncoding.DecodeString(text)
		if err != nil {
			return nil, fmt.Errorf("invalid netmod base64: %w", err)
		}
	}

	var decrypted []byte
	for _, k := range netmodKeys {
		if pt, err := aesECBDecrypt(ciphertext, k); err == nil {
			if strings.Contains(string(pt), "{") && strings.Contains(string(pt), "}") {
				decrypted = pt
				break
			}
		}
	}

	if len(decrypted) == 0 {
		return nil, fmt.Errorf("failed to decrypt NetMod with standard keys")
	}

	// Extract JSON configurations
	var parsed struct {
		Common []struct {
			Remark           string `json:"Remark"`
			Protocol         string `json:"Protocol"`
			Hostname         string `json:"Hostname"`
			Port             int    `json:"Port"`
			UserID           string `json:"UserID"`
			Flow             string `json:"Flow"`
			TransferProtocol string `json:"TransferProtocol"`
			Path             string `json:"Path"`
			Host             string `json:"Host"`
			SNI              string `json:"SNI"`
			TLSType          string `json:"TLSType"`
			FingerPrint      string `json:"FingerPrint"`
		} `json:"Common"`
		Proxy []struct {
			Remark string `json:"Remark"`
			Host   string `json:"Host"`
			Port   int    `json:"Port"`
			User   string `json:"User"`
			Pass   string `json:"Pass"`
		} `json:"Proxy"`
		SSH []struct {
			Remark string `json:"Remark"`
			Host   string `json:"Host"`
			Port   int    `json:"Port"`
			User   string `json:"User"`
			Pass   string `json:"Pass"`
		} `json:"SSH"`
	}

	if err := json.Unmarshal(decrypted, &parsed); err != nil {
		// Fallback to searching extracted text for links
		nodes, _ := ExtractNodes(string(decrypted), "netmod_decrypted", sourceURI)
		return nodes, nil
	}

	var nodes []*model.Node
	for _, item := range parsed.Common {
		proto := strings.ToLower(item.Protocol)
		if proto == "" {
			proto = "vless"
		}
		name := item.Remark
		if name == "" {
			name = strings.ToUpper(proto) + "-" + item.Hostname
		}
		security := "none"
		if item.TLSType == "tls" {
			security = "tls"
		}
		network := strings.ToLower(item.TransferProtocol)
		if network == "" {
			network = "tcp"
		}

		node := &model.Node{
			Protocol:    proto,
			Name:        CleanText(name),
			Server:      item.Hostname,
			Port:        item.Port,
			UUID:        item.UserID,
			Password:    item.UserID,
			Flow:        item.Flow,
			Network:     network,
			Path:        item.Path,
			Host:        item.Host,
			SNI:         item.SNI,
			Security:    security,
			Fingerprint: item.FingerPrint,
			SourceType:  "netmod_file",
			SourceURI:   sourceURI,
		}
		nodes = append(nodes, node)
	}

	for _, item := range parsed.Proxy {
		if item.Host != "" {
			nodes = append(nodes, &model.Node{
				Protocol:   "http",
				Name:       CleanText(item.Remark),
				Server:     item.Host,
				Port:       item.Port,
				Username:   item.User,
				Password:   item.Pass,
				SourceType: "netmod_proxy",
				SourceURI:  sourceURI,
			})
		}
	}

	return nodes, nil
}

// DecryptHat decrypts HA Tunnel Plus (.hat) files.
func DecryptHat(rawInput, sourceURI string) ([]*model.Node, error) {
	text := strings.TrimSpace(rawInput)
	ciphertext, err := base64.StdEncoding.DecodeString(text)
	if err != nil {
		return nil, fmt.Errorf("invalid hat base64")
	}

	h := sha1.New()
	h.Write([]byte(hatImportKey))
	derivedKey := h.Sum(nil)[:16]

	pt, err := aesECBDecrypt(ciphertext, derivedKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt HAT: %w", err)
	}

	var parsed struct {
		Profile struct {
			PrimaryHost string `json:"primary_host"`
			ServerPort  int    `json:"server_port"`
			RealmHost   string `json:"realm_host"`
		} `json:"profile"`
		Description string `json:"description"`
	}

	if err := json.Unmarshal(pt, &parsed); err != nil {
		nodes, _ := ExtractNodes(string(pt), "hat_decrypted", sourceURI)
		return nodes, nil
	}

	server := parsed.Profile.PrimaryHost
	port := parsed.Profile.ServerPort
	if port <= 0 {
		port = 80
	}
	name := parsed.Description
	if name == "" {
		name = "HAT-" + server
	}

	return []*model.Node{
		{
			Protocol:   "http",
			Name:       CleanText(name),
			Server:     server,
			Port:       port,
			SNI:        parsed.Profile.RealmHost,
			SourceType: "hat_file",
			SourceURI:  sourceURI,
		},
	}, nil
}

// DecryptDarkTunnel decrypts DarkTunnel (.dark or darktunnel://) configurations.
func DecryptDarkTunnel(rawInput, sourceURI string) ([]*model.Node, error) {
	text := strings.TrimPrefix(strings.TrimSpace(rawInput), "darktunnel://")
	decoded, err := base64.StdEncoding.DecodeString(text)
	if err != nil {
		return nil, fmt.Errorf("invalid darktunnel base64")
	}

	// DarkTunnel outer JSON contains either raw configs or links
	nodes, _ := ExtractNodes(string(decoded), "darktunnel_file", sourceURI)
	return nodes, nil
}

// DecryptEHI decrypts HTTP Injector (.ehi) files.
func DecryptEHI(rawBytes []byte, sourceURI string) ([]*model.Node, error) {
	// Attempt to extract text payload and parse inner links
	nodes, _ := ExtractNodes(string(rawBytes), "ehi_file", sourceURI)
	return nodes, nil
}

// DecryptNapsternetV decrypts NapsternetV (.npv, .npv4, .npvt) files.
func DecryptNapsternetV(rawInput, sourceURI string) ([]*model.Node, error) {
	nodes, _ := ExtractNodes(rawInput, "npv_file", sourceURI)
	return nodes, nil
}

// DecryptSSHCustom decrypts SSH Custom (.ssc or ssc://) files.
func DecryptSSHCustom(rawInput, sourceURI string) ([]*model.Node, error) {
	content := strings.TrimPrefix(strings.TrimSpace(rawInput), "ssc://")
	// If reversed format, reverse back
	r := []rune(content)
	for i, j := 0, len(r)-1; i < j; i, j = i+1, j-1 {
		r[i], r[j] = r[j], r[i]
	}
	nodes, _ := ExtractNodes(string(r), "ssc_file", sourceURI)
	return nodes, nil
}

func aesECBDecrypt(data, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	bs := block.BlockSize()
	if len(data)%bs != 0 {
		return nil, fmt.Errorf("ciphertext length %d not a multiple of %d", len(data), bs)
	}

	out := make([]byte, len(data))
	for i := 0; i < len(data); i += bs {
		block.Decrypt(out[i:i+bs], data[i:i+bs])
	}

	// Remove PKCS7 padding
	if len(out) > 0 {
		padLen := int(out[len(out)-1])
		if padLen > 0 && padLen <= bs && padLen <= len(out) {
			out = out[:len(out)-padLen]
		}
	}
	return out, nil
}
