package com.example.bureprint

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.ArrayDeque

/**
 * Manages Network Service Discovery (mDNS / DNS-SD) for locating IPP and IPPS printers
 * on the local Wi-Fi network using Android's native NsdManager.
 */
class NsdDiscoveryManager(private val context: Context, messenger: BinaryMessenger) {

    companion object {
        private const val TAG = "NsdDiscoveryManager"
        private const val METHOD_CHANNEL = "org.bureprint/nsd_discovery"
        private const val EVENTS_CHANNEL = "org.bureprint/nsd_events"

        private const val SERVICE_TYPE_IPP = "_ipp._tcp"
        private const val SERVICE_TYPE_IPPS = "_ipps._tcp"
        private const val RESOLVE_TIMEOUT_MS = 6000L
    }

    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var methodChannel: MethodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private var eventChannel: EventChannel = EventChannel(messenger, EVENTS_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null

    private var multicastLock: WifiManager.MulticastLock? = null
    private var isScanning = false

    private var ippDiscoveryListener: NsdManager.DiscoveryListener? = null
    private var ippsDiscoveryListener: NsdManager.DiscoveryListener? = null

    // FIFO Queue for serializing service resolution to prevent NsdManager FAILURE_ALREADY_ACTIVE
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var isResolving = false
    private var resolveTimeoutRunnable: Runnable? = null

    init {
        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                stopDiscoveryInternal()
            }
        })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDiscovery" -> {
                val started = startDiscoveryInternal()
                result.success(started)
            }
            "stopDiscovery" -> {
                stopDiscoveryInternal()
                result.success(true)
            }
            "isScanning" -> {
                result.success(isScanning)
            }
            else -> result.notImplemented()
        }
    }

    @Synchronized
    private fun startDiscoveryInternal(): Boolean {
        if (nsdManager == null) {
            Log.e(TAG, "NsdManager is not available on this device")
            return false
        }

        if (isScanning) {
            return true
        }

        acquireMulticastLock()
        isScanning = true

        synchronized(resolveQueue) {
            resolveQueue.clear()
            isResolving = false
        }

        // 1. Discover Plain IPP printers (_ipp._tcp)
        ippDiscoveryListener = createDiscoveryListener("IPP")
        try {
            nsdManager.discoverServices(SERVICE_TYPE_IPP, NsdManager.PROTOCOL_DNS_SD, ippDiscoveryListener)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start IPP discovery: ${e.message}")
        }

        // 2. Discover Secure IPPS printers (_ipps._tcp)
        ippsDiscoveryListener = createDiscoveryListener("IPPS")
        try {
            nsdManager.discoverServices(SERVICE_TYPE_IPPS, NsdManager.PROTOCOL_DNS_SD, ippsDiscoveryListener)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start IPPS discovery: ${e.message}")
        }

        postToMain {
            eventSink?.success(mapOf("event" to "discoveryStarted"))
        }

        return true
    }

    @Synchronized
    private fun stopDiscoveryInternal() {
        if (!isScanning) return
        isScanning = false

        cancelResolveTimeout()

        synchronized(resolveQueue) {
            resolveQueue.clear()
            isResolving = false
        }

        try {
            ippDiscoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping IPP discovery: ${e.message}")
        }
        ippDiscoveryListener = null

        try {
            ippsDiscoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping IPPS discovery: ${e.message}")
        }
        ippsDiscoveryListener = null

        releaseMulticastLock()

        postToMain {
            eventSink?.success(mapOf("event" to "discoveryStopped"))
        }
    }

    private fun createDiscoveryListener(tag: String): NsdManager.DiscoveryListener {
        return object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {
                Log.d(TAG, "[$tag] Discovery started for $regType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "[$tag] Service found: ${serviceInfo.serviceName} (${serviceInfo.serviceType})")
                enqueueForResolution(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "[$tag] Service lost: ${serviceInfo.serviceName}")
                postToMain {
                    eventSink?.success(
                        mapOf(
                            "event" to "serviceLost",
                            "name" to serviceInfo.serviceName,
                            "serviceType" to serviceInfo.serviceType
                        )
                    )
                }
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "[$tag] Discovery stopped for $serviceType")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "[$tag] Start discovery failed: code $errorCode")
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "[$tag] Stop discovery failed: code $errorCode")
            }
        }
    }

    private fun enqueueForResolution(serviceInfo: NsdServiceInfo) {
        synchronized(resolveQueue) {
            // Avoid duplicate queued requests for the same service name
            val alreadyQueued = resolveQueue.any { it.serviceName == serviceInfo.serviceName && it.serviceType == serviceInfo.serviceType }
            if (!alreadyQueued) {
                resolveQueue.addLast(serviceInfo)
            }
            processNextResolution()
        }
    }

    private fun processNextResolution() {
        synchronized(resolveQueue) {
            if (isResolving || resolveQueue.isEmpty() || !isScanning) return
            isResolving = true
            val serviceToResolve = resolveQueue.removeFirst()

            startResolveTimeout()

            try {
                nsdManager?.resolveService(serviceToResolve, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo?, errorCode: Int) {
                        Log.w(TAG, "Resolve failed for ${serviceInfo?.serviceName}: error $errorCode")
                        finishResolution()
                    }

                    override fun onServiceResolved(resolvedInfo: NsdServiceInfo?) {
                        cancelResolveTimeout()
                        if (resolvedInfo != null) {
                            dispatchResolvedService(resolvedInfo)
                        }
                        finishResolution()
                    }
                })
            } catch (e: Exception) {
                Log.w(TAG, "Exception initiating resolveService: ${e.message}")
                finishResolution()
            }
        }
    }

    private fun finishResolution() {
        cancelResolveTimeout()
        synchronized(resolveQueue) {
            isResolving = false
            processNextResolution()
        }
    }

    private fun startResolveTimeout() {
        cancelResolveTimeout()
        val timeoutRunnable = Runnable {
            Log.w(TAG, "Service resolve timed out, skipping to next")
            finishResolution()
        }
        resolveTimeoutRunnable = timeoutRunnable
        mainHandler.postDelayed(timeoutRunnable, RESOLVE_TIMEOUT_MS)
    }

    private fun cancelResolveTimeout() {
        resolveTimeoutRunnable?.let {
            mainHandler.removeCallbacks(it)
            resolveTimeoutRunnable = null
        }
    }

    private fun dispatchResolvedService(info: NsdServiceInfo) {
        val hostAddress = info.host?.hostAddress
        if (hostAddress.isNullOrBlank()) return

        val attributesMap = mutableMapOf<String, String>()
        try {
            for ((key, valueBytes) in info.attributes) {
                if (valueBytes != null) {
                    attributesMap[key] = String(valueBytes, StandardCharsets.UTF_8)
                }
            }
        } catch (_: Exception) {}

        val payload = mapOf(
            "event" to "serviceResolved",
            "name" to info.serviceName,
            "host" to hostAddress,
            "port" to info.port,
            "serviceType" to info.serviceType,
            "attributes" to attributesMap
        )

        postToMain {
            eventSink?.success(payload)
        }
    }

    private fun acquireMulticastLock() {
        try {
            if (multicastLock == null) {
                multicastLock = wifiManager?.createMulticastLock("bureprint_nsd_multicast")?.apply {
                    setReferenceCounted(true)
                    acquire()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Unable to acquire multicast lock: ${e.message}")
        }
    }

    private fun releaseMulticastLock() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Unable to release multicast lock: ${e.message}")
        }
        multicastLock = null
    }

    private fun postToMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    fun cleanUp() {
        stopDiscoveryInternal()
    }
}
