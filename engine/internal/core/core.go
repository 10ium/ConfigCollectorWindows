package core

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/10ium/freedom-config-collector/engine/internal/model"
)

// ProxyCore defines an abstract proxy engine interface.
type ProxyCore interface {
	Name() string
	Supports(node *model.Node) bool
	Dial(ctx context.Context, network, addr string, node *model.Node) (net.Conn, error)
	HTTPClient(ctx context.Context, node *model.Node, timeout time.Duration) (*http.Client, error)
}

// Router dispatches proxy connections to the appropriate core.
type Router struct {
	mihomoCore ProxyCore
	xrayCore   ProxyCore
}

// NewRouter initializes a core router with available core implementations.
func NewRouter(mihomoCore, xrayCore ProxyCore) *Router {
	return &Router{
		mihomoCore: mihomoCore,
		xrayCore:   xrayCore,
	}
}

// GetCore selects the appropriate core for the specified node.
func (r *Router) GetCore(node *model.Node) (ProxyCore, error) {
	if r.mihomoCore != nil && r.mihomoCore.Supports(node) {
		return r.mihomoCore, nil
	}
	if r.xrayCore != nil && r.xrayCore.Supports(node) {
		return r.xrayCore, nil
	}
	return nil, fmt.Errorf("no supported core found for protocol: %s", node.Protocol)
}
