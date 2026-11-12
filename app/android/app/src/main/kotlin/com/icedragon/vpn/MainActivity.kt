package com.icedragon.vpn

import android.Manifest
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.StatFs
import android.os.storage.StorageManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import android.service.quicksettings.TileService
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The Flutter UI. Channel "app/android": dataDir, startCore (with the proxy
 * off), setOn, isRunning, openUrl. The UI talks to the core itself through
 * its HTTP API on loopback, as on the desktop.
 */
class MainActivity : FlutterActivity() {
    private var androidChannel: MethodChannel? = null
    /** Waits for the user's answer to the VPN permission. */
    private var pendingOn: Result? = null
    // A backup waiting for the place the user picks to save it.
    private var pendingSave: Pair<ByteArray, Result>? = null
    // A backup being picked to open.
    private var pendingOpen: Result? = null
    // Package removal dialog waiting for system completion.
    private var pendingUninstall: Pair<String, Result>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        holdPhoneUpright(resources.configuration)
        super.onCreate(savedInstanceState)
        removeOtherCards()
    }

    /** A tile long-press returns an already open UI to its home page. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == TileService.ACTION_QS_TILE_PREFERENCES) {
            androidChannel?.invokeMethod("openHome", null)
        }
    }

    /**
     * One card in the recent apps. A card stays there after Back, and with no
     * task affinity (the manifest's, against task hijacking) Android keeps it
     * beside a new task opened with another intent: from the notification,
     * the tile, the widget, or the installer's Open.
     */
    private fun removeOtherCards() {
        for (task in getSystemService(ActivityManager::class.java).appTasks) {
            try {
                @Suppress("DEPRECATION") // taskId came only with Android 10.
                if (task.taskInfo.persistentId != taskId) task.finishAndRemoveTask()
            } catch (e: IllegalArgumentException) {
                // That task went by itself meanwhile.
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        holdPhoneUpright(newConfig)
    }

    /**
     * A phone stays upright (its layout is made for it); a tablet, whose
     * shorter side is 600 dp or more, turns freely. Asked again when the
     * screen changes, so a foldable follows its folding. A TV (960 x 540 dp,
     * so "short" too) cannot turn: it keeps its own orientation.
     */
    private fun holdPhoneUpright(config: Configuration) {
        val wanted = if (config.smallestScreenWidthDp < 600 && !isTv(config)) {
            ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } else {
            ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        if (requestedOrientation != wanted) requestedOrientation = wanted
    }

    /** Whether this is a TV (Android TV, Google TV), worked with a remote. */
    private fun isTv(config: Configuration) =
        config.uiMode and Configuration.UI_MODE_TYPE_MASK == Configuration.UI_MODE_TYPE_TELEVISION

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/android")
        androidChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "dataDir" -> result.success(CoreService.dataDir(this).absolutePath)
                "startCore" -> inBackground(result) {
                    CoreService.startCore(this, on = false)
                    CoreService.coreError().ifBlank { null }
                }
                "setOn" -> {
                    if (call.argument<Boolean>("on") != true) {
                        CoreService.turnOff(this)
                        result.success(null)
                    } else {
                        askForNotifications()
                        // The first time, Android asks the user to allow the
                        // VPN; proxy mode needs no VPN.
                        val consent = if (CoreService.usesVpn(this)) VpnService.prepare(this) else null
                        if (consent == null) {
                            turnOn(result)
                        } else {
                            pendingOn?.error("vpn_denied", "superseded", null)
                            pendingOn = result
                            startActivityForResult(consent, VPN_REQUEST)
                        }
                    }
                }
                "isRunning" -> result.success(
                    try {
                        mobile.Mobile.running()
                    } catch (e: Throwable) {
                        CoreService.recordStartError(e)
                        false
                    },
                )
                "coreError" -> result.success(CoreService.coreError())
                "connectionMode" -> result.success(CoreService.connectionMode(this))
                "showSpeed" -> result.success(CoreService.showSpeed(this))
                "setShowSpeed" -> {
                    CoreService.setShowSpeed(this, call.argument<Boolean>("on") == true)
                    result.success(null)
                }
                "setConnectionMode" -> {
                    val mode = call.argument<String>("mode") ?: CoreService.MODE_VPN
                    // A running proxy switched to the VPN needs the permission
                    // first; the app turns it off and on again to ask.
                    if (CoreService.on && mode == CoreService.MODE_VPN && VpnService.prepare(this) != null) {
                        result.error("vpn_denied", "the VPN is not allowed yet", null)
                    } else {
                        CoreService.setConnectionMode(this, mode)
                        result.success(null)
                    }
                }
                "installedApps" -> inBackground(result) { installedApps() }
                "installedAppsDetailed" -> inBackground(result) { installedAppsDetailed() }
                "deviceInfo" -> inBackground(result) { deviceInfo() }
                "appIcon" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    inBackground(result) { appIcon(pkg) }
                }
                "openAppSettings" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(openAppSettings(pkg))
                }
                "uninstallApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    uninstallApp(pkg, result)
                }
                "launchApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    result.success(launchApp(pkg))
                }
                "boostMemory" -> {
                    val exclude = (call.argument<List<String>>("exclude") ?: emptyList()).toSet()
                    inBackground(result) { boostMemory(exclude) }
                }
                "openUsageAccessSettings" -> {
                    result.success(openUsageAccessSettings())
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val subject = call.argument<String>("subject") ?: ""
                    result.success(shareText(text, subject))
                }
                "openStore" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val store = call.argument<String>("store") ?: ""
                    val fallbackUrl = call.argument<String>("fallbackUrl") ?: ""
                    result.success(openStore(pkg, store, fallbackUrl))
                }
                "saveSecret" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    inBackground(result) { saveSecret(key, value) }
                }
                "readSecret" -> {
                    val key = call.argument<String>("key") ?: ""
                    inBackground(result) { readSecret(key) }
                }
                "appRouting" -> inBackground(result) {
                    // The page shows the region's apps installed since the
                    // last look checked; the VPN takes them at once.
                    if (CoreService.appMode(this) == CoreService.MODE_EXCLUDE &&
                        CoreService.suggest(this, force = true)
                    ) {
                        CoreService.reconnect(this)
                    }
                    mapOf(
                        "mode" to CoreService.appMode(this),
                        "bypass" to CoreService.appSet(this, CoreService.BYPASS).toList(),
                        "only" to CoreService.appSet(this, CoreService.ONLY).toList(),
                        "declined" to CoreService.appSet(this, CoreService.DECLINED).toList(),
                        "region" to CoreService.regionAppList(),
                    )
                }
                "setAppRouting" -> {
                    fun set(key: String) = (call.argument<List<String>>(key) ?: emptyList()).toSet()
                    CoreService.setAppRouting(
                        this,
                        call.argument<String>("mode") ?: CoreService.MODE_EXCLUDE,
                        mapOf(
                            CoreService.BYPASS to set("bypass"),
                            CoreService.ONLY to set("only"),
                            CoreService.DECLINED to set("declined"),
                        ),
                    )
                    if (call.argument<Boolean>("apply") == true) CoreService.reconnect(this)
                    result.success(null)
                }
                // The browser sign-in's WebView goes through the core's
                // sign-in proxy (an address), or straight out again (null).
                // The override covers every WebView of this app, and takes
                // effect once the callback runs.
                "setWebViewProxy" -> {
                    if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val address = call.argument<String>("address")
                    val proxies = ProxyController.getInstance()
                    val done = Runnable { result.success(true) }
                    val onMain = Executor { main.post(it) }
                    if (address.isNullOrEmpty()) {
                        proxies.clearProxyOverride(onMain, done)
                    } else {
                        proxies.setProxyOverride(
                            ProxyConfig.Builder().addProxyRule(address).build(),
                            onMain,
                            done,
                        )
                    }
                }
                // Saves a file (a backup) where the user picks, with the
                // system's own dialog: no storage permission. Answers the
                // file's name, or null when the user backs out.
                "saveFile" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("no_data", "nothing to save", null)
                        return@setMethodCallHandler
                    }
                    pendingSave?.second?.success(null)
                    pendingSave = bytes to result
                    val create = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(call.argument<String>("mime") ?: "application/octet-stream")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "backup")
                    try {
                        startActivityForResult(create, SAVE_REQUEST)
                    } catch (e: ActivityNotFoundException) {
                        pendingSave = null
                        result.error("no_picker", "this device has no file picker", null)
                    }
                }
                // Opens a file (a backup) the user picks, with the system's
                // own dialog, and answers its bytes, or null when the user
                // backs out. It reads to the end: the size a provider
                // reports can be wrong (0 for a file written through it).
                "openFile" -> {
                    pendingOpen?.success(null)
                    pendingOpen = result
                    val open = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                        .putExtra(Intent.EXTRA_MIME_TYPES, call.argument<List<String>>("mimes")?.toTypedArray())
                    try {
                        startActivityForResult(open, OPEN_REQUEST)
                    } catch (e: ActivityNotFoundException) {
                        pendingOpen = null
                        result.error("no_picker", "this device has no file picker", null)
                    }
                }
                // The phone's main processor type (arm64-v8a, armeabi-v7a, ...).
                "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")
                "isTv" -> result.success(isTv(resources.configuration))
                "routingCountries" -> inBackground(result) { routingCountries() }
                "openVpnSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    val view = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    try {
                        // A TV without a browser does not throw: its stub
                        // "browser" only shows Android's "no app" message.
                        val handlers = packageManager.queryIntentActivities(view, 0)
                            .filter { it.activityInfo.packageName != "com.android.tv.frameworkpackagestubs" }
                        if (handlers.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        startActivity(view)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Country codes for first-run routing; no phone or location permissions. */
    private fun routingCountries(): Map<String, String> {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            return emptyMap()
        }
        val service = getSystemService(TelephonyManager::class.java) ?: return emptyMap()
        // On dual-SIM devices use the subscription selected for mobile data.
        val phone = runCatching {
            val subscription = SubscriptionManager.getDefaultDataSubscriptionId()
            if (subscription >= 0) {
                service.createForSubscriptionId(subscription)
            } else {
                service
            }
        }.getOrDefault(service)
        return mapOf(
            "network_country" to runCatching { phone.networkCountryIso ?: "" }.getOrDefault(""),
            "sim_country" to runCatching { phone.simCountryIso ?: "" }.getOrDefault("")
        )
    }

    /** Runs [work] off the UI thread and answers with its value. */
    private fun inBackground(result: Result, work: () -> Any?) {
        worker.execute {
            val value = try {
                work()
            } catch (e: Throwable) {
                null
            }
            main.post { result.success(value) }
        }
    }

    /**
     * The installed apps but this one: package, name, and whether it has a
     * launcher icon, on a phone's home screen or a TV's (the others are
     * mostly the system's). Packages without code (overlays, resources) use
     * no network and are left out.
     */
    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        val withIcon = listOf(Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_LEANBACK_LAUNCHER)
            .flatMap { pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(it), 0) }
            .map { it.activityInfo.packageName }
            .toSet()
        @Suppress("DEPRECATION")
        return pm.getInstalledApplications(0)
            .filter { it.packageName != packageName && (it.flags and ApplicationInfo.FLAG_HAS_CODE) != 0 }
            .map {
                mapOf(
                    "package" to it.packageName,
                    "label" to it.loadLabel(pm).toString(),
                    "launcher" to (it.packageName in withIcon),
                )
            }
    }

    /** An app's icon as a small PNG. */
    private fun appIcon(pkg: String): ByteArray {
        val drawable = packageManager.getApplicationIcon(pkg)
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun deviceInfo(): Map<String, Any> {
        val am = getSystemService(ActivityManager::class.java)
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        val stat = StatFs(Environment.getDataDirectory().path)
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to (Build.VERSION.RELEASE ?: ""),
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "model" to (Build.MODEL ?: ""),
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "totalRamBytes" to memInfo.totalMem,
            "availRamBytes" to memInfo.availMem,
            "totalStorageBytes" to stat.totalBytes,
            "freeStorageBytes" to stat.availableBytes,
            "hasUsageAccess" to hasUsageAccess(),
        )
    }

    private fun installedAppsDetailed(): List<Map<String, Any>> {
        val pm = packageManager
        val withIcon = listOf(Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_LEANBACK_LAUNCHER)
            .flatMap { pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(it), 0) }
            .map { it.activityInfo.packageName }
            .toSet()
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }
        val usageOk = hasUsageAccess()
        val storageStats = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && usageOk) {
            getSystemService(StorageStatsManager::class.java)
        } else {
            null
        }
        val user = Process.myUserHandle()
        val result = ArrayList<Map<String, Any>>(packages.size)
        for (pkgInfo in packages) {
            val appInfo = pkgInfo.applicationInfo ?: continue
            if (appInfo.packageName == packageName) continue
            if ((appInfo.flags and ApplicationInfo.FLAG_HAS_CODE) == 0) continue

            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            val verCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode.toLong()
            }
            val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) appInfo.category else -1
            @Suppress("DEPRECATION")
            val isGame = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) category == ApplicationInfo.CATEGORY_GAME else false) ||
                ((appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0)
            val minSdk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) appInfo.minSdkVersion else 24
            val installer = runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgInfo.packageName).installingPackageName ?: ""
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgInfo.packageName) ?: ""
                }
            }.getOrDefault("")

            var apkBytes = 0L
            appInfo.sourceDir?.let { path ->
                val f = File(path)
                if (f.exists()) apkBytes += f.length()
            }
            appInfo.splitSourceDirs?.forEach { path ->
                val f = File(path)
                if (f.exists()) apkBytes += f.length()
            }

            var dataBytes = 0L
            var cacheBytes = 0L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && storageStats != null) {
                runCatching {
                    val uuid = runCatching { appInfo.storageUuid }.getOrNull() ?: StorageManager.UUID_DEFAULT
                    val stats = storageStats.queryStatsForPackage(uuid, pkgInfo.packageName, user)
                    if (stats.appBytes > apkBytes) apkBytes = stats.appBytes
                    dataBytes = stats.dataBytes
                    cacheBytes = stats.cacheBytes
                }
            }

            val reqPerms = pkgInfo.requestedPermissions?.filterNotNull() ?: emptyList()
            val permFlags = pkgInfo.requestedPermissionsFlags
            val grantedPerms = ArrayList<String>()
            if (permFlags != null) {
                for (i in reqPerms.indices) {
                    if (i < permFlags.size && (permFlags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0) {
                        grantedPerms.add(reqPerms[i])
                    }
                }
            }

            result.add(
                mapOf(
                    "package" to pkgInfo.packageName,
                    "label" to appInfo.loadLabel(pm).toString(),
                    "launcher" to (pkgInfo.packageName in withIcon),
                    "system" to isSystem,
                    "versionName" to (pkgInfo.versionName ?: ""),
                    "versionCode" to verCode,
                    "firstInstallTime" to pkgInfo.firstInstallTime,
                    "lastUpdateTime" to pkgInfo.lastUpdateTime,
                    "category" to category,
                    "isGame" to isGame,
                    "minSdk" to minSdk,
                    "targetSdk" to appInfo.targetSdkVersion,
                    "installer" to installer,
                    "apkBytes" to apkBytes,
                    "dataBytes" to dataBytes,
                    "cacheBytes" to cacheBytes,
                    "permissions" to reqPerms,
                    "grantedPermissions" to grantedPerms,
                ),
            )
        }
        return result
    }

    private fun openAppSettings(pkg: String): Boolean = runCatching {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        true
    }.getOrDefault(false)

    private fun isPackageInstalled(pkg: String): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
        }
        true
    }.getOrDefault(false)

    private fun uninstallApp(pkg: String, result: Result) {
        if (pkg.isBlank() || pkg == packageName || !isPackageInstalled(pkg)) {
            result.success(false)
            return
        }
        pendingUninstall?.second?.success(false)
        pendingUninstall = pkg to result
        val intent = Intent(Intent.ACTION_DELETE).apply {
            data = Uri.parse("package:$pkg")
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }
        try {
            startActivityForResult(intent, UNINSTALL_REQUEST)
        } catch (e: Exception) {
            pendingUninstall = null
            result.success(false)
        }
    }

    private fun launchApp(pkg: String): Boolean = runCatching {
        val pm = packageManager
        val intent = pm.getLaunchIntentForPackage(pkg)
            ?: if (isTv(resources.configuration)) pm.getLeanbackLaunchIntentForPackage(pkg) else null
        if (intent == null) return@runCatching false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    }.getOrDefault(false)

    private fun boostMemory(exclude: Set<String>): Map<String, Any> {
        val am = getSystemService(ActivityManager::class.java) ?: return emptyMap()
        val beforeInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(beforeInfo)
        val beforeRunning = runCatching {
            am.runningAppProcesses
                ?.mapNotNull { it.processName?.substringBefore(':') }
                ?.toSet()
        }.getOrNull() ?: emptySet()
        val pm = packageManager
        @Suppress("DEPRECATION")
        val apps = pm.getInstalledApplications(0)
        for (app in apps) {
            val pkg = app.packageName
            if (pkg == packageName || pkg in exclude) continue
            if ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0) continue
            if ((app.flags and ApplicationInfo.FLAG_PERSISTENT) != 0) continue
            runCatching { am.killBackgroundProcesses(pkg) }
        }
        System.gc()
        val afterRunning = runCatching {
            am.runningAppProcesses
                ?.mapNotNull { it.processName?.substringBefore(':') }
                ?.toSet()
        }.getOrNull() ?: emptySet()
        val confirmedStopped = beforeRunning.count { pkg ->
            pkg != packageName && pkg !in exclude && pkg !in afterRunning
        }
        val afterInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(afterInfo)
        return mapOf(
            "beforeAvailBytes" to beforeInfo.availMem,
            "afterAvailBytes" to afterInfo.availMem,
            "totalBytes" to afterInfo.totalMem,
            "touchedCount" to confirmedStopped,
        )
    }

    private fun openUsageAccessSettings(): Boolean = runCatching {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    }.getOrDefault(false)

    private fun shareText(text: String, subject: String): Boolean = runCatching {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (subject.isNotBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        startActivity(Intent.createChooser(send, subject.ifBlank { getString(R.string.app_name) }))
        true
    }.getOrDefault(false)

    private fun openStore(pkg: String, store: String, fallbackUrl: String): Boolean {
        val validPkg = Regex("^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+$").matches(pkg)
        val deepUri = if (validPkg) {
            when (store) {
                "bazaar" -> "bazaar://details?id=$pkg"
                "myket" -> "myket://details?id=$pkg"
                "googlePlay" -> "market://details?id=$pkg"
                else -> ""
            }
        } else {
            ""
        }
        if (deepUri.isNotEmpty()) {
            val launched = runCatching {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepUri)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            }.getOrDefault(false)
            if (launched) return true
        }
        val parsedFallback = runCatching { Uri.parse(fallbackUrl.trim()) }.getOrNull()
        if (parsedFallback != null &&
            parsedFallback.scheme.equals("https", ignoreCase = true) &&
            !parsedFallback.host.isNullOrBlank()
        ) {
            return runCatching {
                startActivity(
                    Intent(Intent.ACTION_VIEW, parsedFallback).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
                true
            }.getOrDefault(false)
        }
        return false
    }

    private fun getOrCreateAesKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val existing = ks.getEntry(HUB_KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(
                HUB_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun saveSecret(key: String, value: String): Boolean {
        if (key.isBlank()) return false
        val prefs = getSharedPreferences(HUB_SECURE_PREFS, Context.MODE_PRIVATE)
        if (value.isBlank()) {
            prefs.edit().remove(key).apply()
            return true
        }
        return runCatching {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateAesKey())
            val iv = cipher.iv
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val combined = ByteArray(iv.size + encrypted.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(encrypted, 0, combined, iv.size, encrypted.size)
            prefs.edit().putString(key, Base64.encodeToString(combined, Base64.NO_WRAP)).apply()
            true
        }.getOrDefault(false)
    }

    private fun readSecret(key: String): String {
        if (key.isBlank()) return ""
        val prefs = getSharedPreferences(HUB_SECURE_PREFS, Context.MODE_PRIVATE)
        val encoded = prefs.getString(key, null) ?: return ""
        return runCatching {
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            if (combined.size <= GCM_IV_LEN) return ""
            val iv = combined.copyOfRange(0, GCM_IV_LEN)
            val ciphertext = combined.copyOfRange(GCM_IV_LEN, combined.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateAesKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(ciphertext), Charsets.UTF_8)
        }.getOrElse {
            prefs.edit().remove(key).apply()
            ""
        }
    }

    private fun turnOn(result: Result) {
        try {
            CoreService.turnOn(this)
            result.success(null)
        } catch (e: Exception) {
            result.error("start_failed", e.message, null)
        }
    }

    @Deprecated("The VPN permission is asked with startActivityForResult.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAVE_REQUEST) {
            saved(resultCode, data?.data)
            return
        }
        if (requestCode == OPEN_REQUEST) {
            opened(resultCode, data?.data)
            return
        }
        if (requestCode == UNINSTALL_REQUEST) {
            val (pkg, pending) = pendingUninstall ?: return
            pendingUninstall = null
            pending.success(resultCode == RESULT_OK || !isPackageInstalled(pkg))
            return
        }
        if (requestCode != VPN_REQUEST) return
        val result = pendingOn ?: return
        pendingOn = null
        if (resultCode == RESULT_OK) turnOn(result) else result.error("vpn_denied", "the VPN was not allowed", null)
    }

    /** Writes the pending file to [uri], the place the user picked. */
    private fun saved(resultCode: Int, uri: Uri?) {
        val (bytes, result) = pendingSave ?: return
        pendingSave = null
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        worker.execute {
            val name = try {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("the file could not be opened")
                displayName(uri)
            } catch (e: Exception) {
                main.post { result.error("write_failed", e.message, null) }
                return@execute
            }
            main.post { result.success(name) }
        }
    }

    /** Reads the picked file at [uri], to the end. */
    private fun opened(resultCode: Int, uri: Uri?) {
        val result = pendingOpen ?: return
        pendingOpen = null
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        worker.execute {
            val bytes = try {
                contentResolver.openInputStream(uri)?.use { input ->
                    val out = ByteArrayOutputStream()
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        // A backup is a few kilobytes; nothing sensible is this big.
                        if (out.size() > MAX_OPEN_BYTES) throw IllegalStateException("the file is too large")
                    }
                    out.toByteArray()
                } ?: throw IllegalStateException("the file could not be opened")
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
                return@execute
            }
            main.post { result.success(bytes) }
        }
    }

    private fun displayName(uri: Uri): String =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: uri.lastPathSegment ?: ""

    override fun onDestroy() {
        pendingUninstall?.second?.success(false)
        pendingUninstall = null
        // Off, nothing needs the core once the UI is gone.
        if (isFinishing && !CoreService.on) CoreService.stopCore()
        super.onDestroy()
    }

    companion object {
        private const val VPN_REQUEST = 7
        private const val SAVE_REQUEST = 8
        private const val OPEN_REQUEST = 9
        private const val UNINSTALL_REQUEST = 10
        private const val MAX_OPEN_BYTES = 16 * 1024 * 1024
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val HUB_KEY_ALIAS = "icedragon_hub_secrets_v1"
        private const val HUB_SECURE_PREFS = "hub_secure"
        private const val GCM_IV_LEN = 12
    }

    /** The service's notification needs this on Android 13 and later. */
    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}
