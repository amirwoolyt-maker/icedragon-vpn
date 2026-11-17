package com.icedragon.vpn

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

/** The Quick Settings tile: turns the VPN on or off without the app. */
class QuickTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        show()
    }

    override fun onClick() {
        super.onClick()
        if (!CoreService.isProActive(this)) {
            // Quick tiles are an exclusive VIP feature: redirect non-pro users to upgrade
            openApp("pro")
            show()
            refresh(this)
            return
        }
        if (CoreService.on && !CoreService.isDnsOnly) {
            // VPN is already on: clicking it turns off both modes.
            CoreService.turnOff(this)
        } else if (CoreService.usesVpn(this) && VpnService.prepare(this) != null) {
            // The VPN permission is asked in the app.
            openApp()
        } else {
            try {
                // Starts VPN mode (if DNS-only was active, it stops DNS first).
                CoreService.turnOn(this, dnsOnly = false)
            } catch (e: Exception) {
                // Android refused to start the service from here: the app
                // opens, and its button turns it on.
                Log.w("QuickTile", "starting the service failed; opening the app", e)
                openApp()
            }
        }
        show()
        refresh(this)
    }

    private fun show() {
        val tile = qsTile ?: return
        tile.state = if (CoreService.on && !CoreService.isDnsOnly) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.quick_tile_vpn)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (!CoreService.isProActive(this)) "VIP" else null
        }
        tile.updateTile()
    }

    private fun openApp(route: String? = null) {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (route != null) {
            intent.putExtra("route", route)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }

    companion object {
        /** Asks the system to show both tiles' states again. */
        fun refresh(context: Context) {
            try {
                TileService.requestListeningState(context, ComponentName(context, QuickTile::class.java))
                DnsQuickTile.refresh(context)
            } catch (ignored: Throwable) {}
        }
    }
}
