// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package main

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/vishvananda/netlink"
	"golang.org/x/sys/unix"
)

type NetworkInfo struct {
	Address  string `json:"address,omitempty"`
	Hostname string `json:"hostname,omitempty"`
	IsLocal  bool   `json:"is_local,omitempty"`
}

type hostnameLookupResult struct {
	address  string
	hostname string
	isLocal  bool
}
type NetworkMonitor struct {
	linkUpdates   chan netlink.LinkUpdate
	addrUpdates   chan netlink.AddrUpdate
	routeUpdates  chan netlink.RouteUpdate
	done          chan struct{}
	infos         []NetworkInfo
	mutex         sync.RWMutex
	onUpdate      func([]NetworkInfo)
	currentCancel context.CancelFunc
	cancelMutex   sync.Mutex
}

func NewNetworkMonitor(onUpdate func([]NetworkInfo)) (*NetworkMonitor, error) {
	linkChan := make(chan netlink.LinkUpdate)
	addrChan := make(chan netlink.AddrUpdate)
	routeChan := make(chan netlink.RouteUpdate)
	done := make(chan struct{})

	if err := netlink.LinkSubscribe(linkChan, done); err != nil {
		return nil, fmt.Errorf("failed to subscribe to link updates: %w", err)
	}
	if err := netlink.AddrSubscribe(addrChan, done); err != nil {
		return nil, fmt.Errorf("failed to subscribe to address updates: %w", err)
	}

	// Subscribe to all routing tables
	options := netlink.RouteSubscribeOptions{
		ErrorCallback: func(err error) {
			logger.Printf("Route subscription error: %v", err)
		},
		ListExisting: true,
	}
	if err := netlink.RouteSubscribeWithOptions(routeChan, done, options); err != nil {
		return nil, fmt.Errorf("failed to subscribe to route updates: %w", err)
	}

	return &NetworkMonitor{
		linkUpdates:  linkChan,
		addrUpdates:  addrChan,
		routeUpdates: routeChan,
		done:         done,
		onUpdate:     onUpdate,
	}, nil
}

func (nm *NetworkMonitor) findCGNATAddresses() ([]NetworkInfo, error) {
	// Cancel previous lookup if any
	nm.cancelMutex.Lock()
	if nm.currentCancel != nil {
		nm.currentCancel()
	}
	ctx, cancel := context.WithCancel(context.Background())
	nm.currentCancel = cancel
	nm.cancelMutex.Unlock()

	// Find CGNAT interface
	links, err := netlink.LinkList()
	if err != nil {
		return nil, fmt.Errorf("failed to list interfaces: %w", err)
	}

	var (
		infos      []NetworkInfo
		wg         sync.WaitGroup
		localAddr  string
		cgnatIface netlink.Link
		resultChan = make(chan hostnameLookupResult)
	)
	for _, link := range links {
		addrs, err := netlink.AddrList(link, netlink.FAMILY_V4)
		if err != nil {
			logger.Printf("Failed to get interface %v address list: %v", link.Attrs().Name, err)
			continue
		}
		for _, addr := range addrs {
			logger.Printf("Addr=%v\n", addr.IP.String())
			if isCGNATAddress(addr.IP.String()) {
				localAddr = addr.IP.String()
				cgnatIface = link
				break
			}
		}
		if cgnatIface != nil {
			break
		}
	}
	if localAddr == "" || cgnatIface == nil {
		logger.Println("No CGNAT interface found. VPN is off?", localAddr)
		return nil, nil
	}
	wg.Add(1)
	go func() {
		defer wg.Done()
		select {
		case <-ctx.Done():
			return
		case resultChan <- hostnameLookupResult{
			address:  localAddr,
			hostname: getHostnameWithContext(ctx, localAddr),
			isLocal:  true,
		}:
		}
	}()

	// Get routes from all tables associated with CGNAT interface
	filter := &netlink.Route{
		Table:     unix.RT_TABLE_UNSPEC,
		LinkIndex: cgnatIface.Attrs().Index,
	}
	routes, err := netlink.RouteListFiltered(netlink.FAMILY_V4, filter, netlink.RT_FILTER_TABLE|netlink.RT_FILTER_OIF)
	if err != nil {
		return infos, err
	}

	seen := make(map[string]bool)
	seen[localAddr] = true

	for _, route := range routes {
		if route.Dst == nil {
			continue
		}
		if _, bits := route.Dst.Mask.Size(); bits != 32 {
			continue
		}
		addr := route.Dst.IP.String()
		if seen[addr] || !isCGNATAddress(addr) {
			continue
		}
		seen[addr] = true

		wg.Add(1)
		go func(address string) {
			defer wg.Done()
			select {
			case <-ctx.Done():
				return
			case resultChan <- hostnameLookupResult{
				address:  address,
				hostname: getHostnameWithContext(ctx, address),
				isLocal:  false,
			}:
			}
		}(addr)
	}

	go func() {
		wg.Wait()
		close(resultChan)
	}()

	// Collect results with timeout and cancellation
	for {
		select {
		case <-ctx.Done():
			return infos, ctx.Err()
		case result, ok := <-resultChan:
			if !ok {
				return infos, nil
			}
			if result.hostname != "" {
				infos = append(infos, NetworkInfo{
					Address:  result.address,
					Hostname: result.hostname,
					IsLocal:  result.isLocal,
				})
			}
		}
	}
}

func getHostnameWithContext(ctx context.Context, addr string) string {
	lookupDone := make(chan string, 1)
	go func() {
		hostname, err := getHostnameWithRetry(addr)
		if err != nil {
			logger.Printf("Failed to get hostname for %v: %v\n", addr, err)
			lookupDone <- ""
			return
		}
		// Remove the last character if it is '.'
		if len(hostname) > 0 && hostname[len(hostname)-1] == '.' {
			hostname = hostname[:len(hostname)-1]
		}
		logger.Printf("Found hostname %v\n", hostname)
		lookupDone <- hostname
	}()

	select {
	case <-ctx.Done():
		return ""
	case hostname := <-lookupDone:
		return hostname
	case <-time.After(5 * time.Second):
		return ""
	}
}

func (nm *NetworkMonitor) updateNetworkInfo() {
	infos, err := nm.findCGNATAddresses()
	if err != nil {
		logger.Printf("Error finding CGNAT addresses: %v", err)
		return
	}

	nm.mutex.Lock()
	nm.infos = infos
	nm.mutex.Unlock()

	if nm.onUpdate != nil {
		nm.onUpdate(infos)
	}
}

func isCGNATAddress(addr string) bool {
	ip := net.ParseIP(addr)
	if ip == nil {
		return false
	}
	ip = ip.To4()
	if ip == nil {
		return false
	}
	return ip[0] == 100 && (ip[1]&0xC0) == 64
}

func (nm *NetworkMonitor) watchNetworkChanges() {
	for {
		select {
		case update := <-nm.linkUpdates:
			logger.Printf("Network interface %s is UP\n", update.Link.Attrs().Name)
			nm.updateNetworkInfo()
		case update := <-nm.addrUpdates:
			logger.Printf("Address update on interface %v: %v\n", update.LinkIndex, update.NewAddr)
			nm.updateNetworkInfo()
		case update := <-nm.routeUpdates:
			// Filter out empty route updates
			if update.Dst == nil && update.Src == nil && update.Gw == nil && len(update.ListFlags()) == 0 {
				continue
			}

			logger.Printf("Route update: %v\n", update.Route)
			nm.updateNetworkInfo()
		case <-nm.done:
			logger.Println("DONE wacthing network changes.")
			return
		}
	}
}

func (nm *NetworkMonitor) Start() {
	go nm.watchNetworkChanges()
	// Initial update
	nm.updateNetworkInfo()
}

func (nm *NetworkMonitor) Stop() {
	close(nm.done)
}

func (nm *NetworkMonitor) GetCurrentInfo() []NetworkInfo {
	nm.mutex.RLock()
	defer nm.mutex.RUnlock()
	return nm.infos
}

func FindLocalCGNATAddress() (net.IP, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, fmt.Errorf("failed to get interfaces: %w", err)
	}

	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			logger.Printf("failed to get addresses for interface %v: %v\n", iface.Name, err)
			continue
		}

		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}

			if ip.To4() != nil && ip.To4()[0] == 100 && (ip.To4()[1]&0xC0) == 64 {
				logger.Printf("Found CGNAT address %v on interface %v\n", ip, iface.Name)
				return ip, nil
			}
		}
	}
	return nil, fmt.Errorf("no CGNAT address found")
}

func getHostnameWithRetry(ip string) (string, error) {
	const maxRetries = 3
	const initialBackoff = time.Second

	var lastErr error
	for attempt := 0; attempt < maxRetries; attempt++ {
		if attempt > 0 {
			backoff := initialBackoff * time.Duration(1<<uint(attempt))
			time.Sleep(backoff)
		}

		names, err := net.LookupAddr(ip)
		if err != nil {
			lastErr = fmt.Errorf("attempt %d: %w", attempt+1, err)
			continue
		}
		if len(names) > 0 {
			return names[0], nil
		}
	}
	return "", fmt.Errorf("all attempts failed: %w", lastErr)
}
