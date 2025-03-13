// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

interface NetworkMonitorDelegate {
    fun onNetworkConfigUpdated(infos: List<NetworkInfo>)

    fun onNetworkConfigError(error: NetworkError)

    fun onNetworkAvailabilityChanged(available: Boolean)
}

class NetworkMonitor(
    private val context: Context,
    private val delegate: NetworkMonitorDelegate,
) {
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val logger = Logger("NetworkMonitor")
    private var vpnNetwork: Network? = null

    fun start() {
        logger.d("Start network state monitoring")
        connectivityManager.registerDefaultNetworkCallback(
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    scope.launch {
                        logger.d("The default network is now: $network")
                        delegate.onNetworkAvailabilityChanged(true)
                    }
                }

                override fun onLost(network: Network) {
                    scope.launch {
                        logger.d("The application no longer has a default network. The last default network was $network")
                        delegate.onNetworkAvailabilityChanged(false)
                    }
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) {
                    scope.launch {
                        logger.d("The default network changed capabilities: " + networkCapabilities)
                        delegate.onNetworkAvailabilityChanged(
                            networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                                (
                                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) ||
                                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_SATELLITE) ||
                                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_USB) ||
                                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
                                ),
                        )
                    }
                }

                override fun onLinkPropertiesChanged(
                    network: Network,
                    linkProperties: LinkProperties,
                ) {
                    logger.d("The default network changed link properties: " + linkProperties)
                }
            },
        )

        val request =
            NetworkRequest
                .Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .build()

        connectivityManager.registerNetworkCallback(
            request,
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    scope.launch {
                        logger.d("VPN network available: $network")
                        vpnNetwork = network
                        checkNetworkConfig(network)
                    }
                }

                override fun onLost(network: Network) {
                    scope.launch {
                        logger.d("VPN network lost: $network")
                        if (vpnNetwork == network) {
                            vpnNetwork = null
                            delegate.onNetworkConfigUpdated(emptyList())
                        }
                    }
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    caps: NetworkCapabilities,
                ) {
                    scope.launch {
                        val isVPN = caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
                        logger.d("Network capabilities changed: $network, VPN: $isVPN")
                        if (isVPN) {
                            vpnNetwork = network
                            checkNetworkConfig(network)
                        }
                    }
                }
            },
        )
    }

    private suspend fun checkNetworkConfig(network: Network) {
        try {
            val addresses = mutableListOf<NetworkInfo>()
            val lookupJobs = mutableListOf<Deferred<NetworkInfo>>()

            // Find local CGNAT address first
            val localAddress = findCGNATAddress()
            if (localAddress != null) {
                lookupJobs.add(
                    scope.async {
                        NetworkInfo(
                            address = localAddress,
                            hostname = resolveDNS(localAddress),
                            isLocal = true,
                        )
                    },
                )
            }

            // Get routes from VPN interface
            val linkProperties = connectivityManager.getLinkProperties(network)
            val routes = linkProperties?.routes ?: emptyList()

            val seen = mutableSetOf<String>()
            localAddress?.let { seen.add(it) }

            routes.forEach { route ->
                logger.d("Route: $route")
                val address = route.destination?.address?.hostAddress
                if (address != null &&
                    !seen.contains(address) &&
                    route.destination?.prefixLength == 32 &&
                    isCGNATAddress(address)
                ) {
                    seen.add(address)
                    lookupJobs.add(
                        scope.async {
                            NetworkInfo(
                                address = address,
                                hostname = resolveDNS(address),
                                isLocal = false,
                            )
                        },
                    )
                }
            }

            val results = lookupJobs.awaitAll()
            delegate.onNetworkConfigUpdated(results)
        } catch (e: Exception) {
            delegate.onNetworkConfigError(NetworkError.fromException(e))
        }
    }

    private fun findCGNATAddress(): String? =
        NetworkInterface
            .getNetworkInterfaces()
            .asSequence()
            .filter { iface ->
                !iface.isLoopback && (iface.isUp || iface.isVirtual)
            }.flatMap { it.inetAddresses.asSequence() }
            .filter { !it.isLoopbackAddress && it is Inet4Address }
            .map { it.hostAddress }
            .firstOrNull { isCGNATAddress(it) }

    private fun isCGNATAddress(address: String): Boolean {
        val parts = address.split(".")
        if (parts.size != 4) return false

        val firstOctet = parts[0].toIntOrNull() ?: return false
        val secondOctet = parts[1].toIntOrNull() ?: return false

        return firstOctet == 100 && secondOctet in 64..127
    }

    private suspend fun resolveDNS(address: String): String {
        var lastError: Exception? = null
        repeat(3) { attempt ->
            try {
                logger.d("Resolving the hostname for $address $attempt")
                return withContext(Dispatchers.IO) {
                    InetAddress.getByName(address).canonicalHostName
                }
            } catch (e: Exception) {
                lastError = e
                delay(1000L * (attempt + 1))
            }
        }
        throw lastError ?: NetworkError.DNSResolutionFailed
    }

    fun stop() {
        scope.cancel()
    }
}
