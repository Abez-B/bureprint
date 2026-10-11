package com.example.bureprint

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val USB_HOST_CHANNEL = "org.bureprint/usb_host"
        private const val USB_EVENTS_CHANNEL = "org.bureprint/usb_events"
        private const val SHARE_RECEIVER_CHANNEL = "org.bureprint/share_receiver"
        private const val SHARE_EVENTS_CHANNEL = "org.bureprint/share_events"
        private const val ACTION_USB_PERMISSION = "org.bureprint.USB_PERMISSION"
    }

    private var usbMethodChannel: MethodChannel? = null
    private var usbEventSink: EventChannel.EventSink? = null
    private var shareEventSink: EventChannel.EventSink? = null

    private var pendingPermissionResult: MethodChannel.Result? = null

    // Network Service Discovery (mDNS) manager
    private var nsdDiscoveryManager: NsdDiscoveryManager? = null

    // Cache of shared files from initial intent launch
    private val initialSharedFiles = mutableListOf<Map<String, Any?>>()

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        pendingPermissionResult?.success(granted)
                        pendingPermissionResult = null

                        if (granted && device != null) {
                            notifyDeviceAttached(device)
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    if (device != null) {
                        notifyDeviceAttached(device)
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    if (device != null) {
                        notifyDeviceDetached(device.deviceId)
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }

        // Process startup intent for shared/opened files
        handleIncomingIntent(intent, isInitial = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Check for USB attach intent
        if (UsbManager.ACTION_USB_DEVICE_ATTACHED == intent.action) {
            val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            }
            if (device != null) {
                notifyDeviceAttached(device)
            }
        }

        handleIncomingIntent(intent, isInitial = false)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(usbReceiver)
        } catch (_: Exception) {}
        try {
            nsdDiscoveryManager?.cleanUp()
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. USB Host Method Channel
        usbMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_HOST_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                handleUsbMethodCall(call, result)
            }
        }

        // 2. USB Events Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, USB_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                }
            }
        )

        // 3. Share Receiver Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_RECEIVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFiles" -> {
                    val filesCopy = ArrayList(initialSharedFiles)
                    initialSharedFiles.clear()
                    result.success(filesCopy)
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val file = File(path)
                            val uri = Uri.fromFile(file)
                            val scanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri)
                            sendBroadcast(scanIntent)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "openUrl" -> {
                    val urlString = call.argument<String>("url")
                    if (urlString != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlString)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL string cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 4. Share Events Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            }
        )

        // 5. Network Service Discovery (mDNS IPP/IPPS) Manager
        nsdDiscoveryManager = NsdDiscoveryManager(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun handleUsbMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        if (usbManager == null) {
            result.error("USB_UNAVAILABLE", "UsbManager service is null", null)
            return
        }

        when (call.method) {
            "enumerateDevices" -> {
                val deviceList = mutableListOf<Map<String, Any?>>()
                for ((_, device) in usbManager.deviceList) {
                    if (isPrinterDevice(device)) {
                        deviceList.add(deviceToMap(device, usbManager))
                    }
                }
                result.success(deviceList)
            }

            "hasPermission" -> {
                val deviceId = call.argument<Int>("deviceId")
                val device = findDeviceById(usbManager, deviceId)
                if (device != null) {
                    result.success(usbManager.hasPermission(device))
                } else {
                    result.success(false)
                }
            }

            "requestPermission" -> {
                val deviceId = call.argument<Int>("deviceId")
                val device = findDeviceById(usbManager, deviceId)
                if (device == null) {
                    result.success(false)
                    return
                }

                if (usbManager.hasPermission(device)) {
                    result.success(true)
                    return
                }

                pendingPermissionResult = result
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val permissionIntent = PendingIntent.getBroadcast(
                    this,
                    0,
                    Intent(ACTION_USB_PERMISSION).setPackage(packageName),
                    flags
                )
                usbManager.requestPermission(device, permissionIntent)
            }

            "sendBytes" -> {
                val deviceId = call.argument<Int>("deviceId")
                val bytes = call.argument<ByteArray>("bytes") ?: run {
                    val intList = call.argument<List<Int>>("bytes")
                    intList?.map { it.toByte() }?.toByteArray()
                }

                if (bytes == null || deviceId == null) {
                    result.error("INVALID_ARGS", "Missing deviceId or bytes", null)
                    return
                }

                val device = findDeviceById(usbManager, deviceId)
                if (device == null) {
                    result.error("DEVICE_NOT_FOUND", "USB device not found", null)
                    return
                }

                if (!usbManager.hasPermission(device)) {
                    result.error("NO_PERMISSION", "USB permission not granted", null)
                    return
                }

                // Execute transfer on background thread to avoid blocking main thread
                Thread {
                    val success = transmitBytesToUsbPrinter(usbManager, device, bytes)
                    runOnUiThread {
                        result.success(success)
                    }
                }.start()
            }

            else -> result.notImplemented()
        }
    }

    private fun transmitBytesToUsbPrinter(usbManager: UsbManager, device: UsbDevice, data: ByteArray): Boolean {
        var connection: UsbDeviceConnection? = null
        var iface: UsbInterface? = null
        try {
            connection = usbManager.openDevice(device) ?: return false

            // Find printer interface (class 7) or first interface
            var targetInterface: UsbInterface? = null
            var outEndpoint: UsbEndpoint? = null

            for (i in 0 until device.interfaceCount) {
                val itf = device.getInterface(i)
                if (itf.interfaceClass == UsbConstants.USB_CLASS_PRINTER || targetInterface == null) {
                    for (e in 0 until itf.endpointCount) {
                        val ep = itf.getEndpoint(e)
                        if (ep.direction == UsbConstants.USB_DIR_OUT) {
                            targetInterface = itf
                            outEndpoint = ep
                            break
                        }
                    }
                }
                if (targetInterface != null && targetInterface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                    break
                }
            }

            if (targetInterface == null || outEndpoint == null) {
                return false
            }

            iface = targetInterface
            if (!connection.claimInterface(targetInterface, true)) {
                return false
            }

            val chunkSize = outEndpoint.maxPacketSize.coerceAtLeast(4096)
            var offset = 0
            while (offset < data.size) {
                val len = minOf(chunkSize, data.size - offset)
                val buffer = ByteArray(len)
                System.arraycopy(data, offset, buffer, 0, len)
                val transferred = connection.bulkTransfer(outEndpoint, buffer, len, 5000)
                if (transferred < 0) {
                    return false
                }
                offset += len
            }
            return true
        } catch (_: Exception) {
            return false
        } finally {
            try {
                if (iface != null && connection != null) {
                    connection.releaseInterface(iface)
                }
                connection?.close()
            } catch (_: Exception) {}
        }
    }

    private fun isPrinterDevice(device: UsbDevice): Boolean {
        if (device.deviceClass == UsbConstants.USB_CLASS_PRINTER) return true
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                return true
            }
        }
        // Allow composite devices (class 0)
        return device.deviceClass == UsbConstants.USB_CLASS_PER_INTERFACE
    }

    private fun findDeviceById(usbManager: UsbManager, deviceId: Int?): UsbDevice? {
        if (deviceId == null) return null
        return usbManager.deviceList.values.firstOrNull { it.deviceId == deviceId }
    }

    private fun deviceToMap(device: UsbDevice, usbManager: UsbManager): Map<String, Any?> {
        val hasPerm = usbManager.hasPermission(device)
        return mapOf(
            "deviceId" to device.deviceId,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "deviceName" to device.deviceName,
            "manufacturerName" to if (hasPerm) device.manufacturerName else null,
            "productName" to if (hasPerm) device.productName else null,
            "hasPermission" to hasPerm,
            "isIppOverUsb" to (device.deviceSubclass == 0x04)
        )
    }

    private fun notifyDeviceAttached(device: UsbDevice) {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager ?: return
        val map = mapOf(
            "type" to "attached",
            "device" to deviceToMap(device, usbManager)
        )
        runOnUiThread {
            usbEventSink?.success(map)
        }
    }

    private fun notifyDeviceDetached(deviceId: Int) {
        val map = mapOf(
            "type" to "detached",
            "deviceId" to deviceId
        )
        runOnUiThread {
            usbEventSink?.success(map)
        }
    }

    // --- Intent & File Sharing Handlers ---

    private fun handleIncomingIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return
        val action = intent.action ?: return
        val type = intent.type ?: "application/octet-stream"

        val incomingFiles = mutableListOf<Map<String, Any?>>()

        when (action) {
            Intent.ACTION_VIEW -> {
                intent.data?.let { uri ->
                    val fileInfo = copyUriToAppCache(uri, type)
                    if (fileInfo != null) {
                        incomingFiles.add(fileInfo)
                    }
                }
            }
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                if (uri != null) {
                    val fileInfo = copyUriToAppCache(uri, type)
                    if (fileInfo != null) {
                        incomingFiles.add(fileInfo)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                uris?.forEach { uri ->
                    val fileInfo = copyUriToAppCache(uri, type)
                    if (fileInfo != null) {
                        incomingFiles.add(fileInfo)
                    }
                }
            }
        }

        if (incomingFiles.isNotEmpty()) {
            if (isInitial) {
                initialSharedFiles.addAll(incomingFiles)
            } else {
                runOnUiThread {
                    shareEventSink?.success(incomingFiles)
                }
            }
        }
    }

    private fun copyUriToAppCache(uri: Uri, mimeType: String): Map<String, Any?>? {
        return try {
            val contentResolver = applicationContext.contentResolver
            var fileName = "imported_${System.currentTimeMillis()}"

            // Query original filename from ContentResolver
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && cursor.moveToFirst()) {
                    val queryName = cursor.getString(nameIndex)
                    if (!queryName.isNullOrBlank()) {
                        fileName = queryName
                    }
                }
            }

            // Ensure valid extension based on MIME type if none present
            if (!fileName.contains(".")) {
                val ext = when {
                    mimeType.contains("pdf") -> ".pdf"
                    mimeType.contains("jpeg") || mimeType.contains("jpg") -> ".jpg"
                    mimeType.contains("png") -> ".png"
                    mimeType.contains("wordprocessingml") -> ".docx"
                    mimeType.contains("msword") -> ".doc"
                    mimeType.contains("opendocument") -> ".odt"
                    mimeType.contains("plain") -> ".txt"
                    else -> ".bin"
                }
                fileName += ext
            }

            val cacheDir = File(applicationContext.cacheDir, "shared_documents")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            val destinationFile = File(cacheDir, "${System.currentTimeMillis()}_$fileName")
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream == null) return null

            inputStream.use { input ->
                FileOutputStream(destinationFile).use { output ->
                    input.copyTo(output)
                }
            }

            mapOf(
                "filePath" to destinationFile.absolutePath,
                "mimeType" to mimeType,
                "name" to fileName
            )
        } catch (_: Exception) {
            null
        }
    }
}
