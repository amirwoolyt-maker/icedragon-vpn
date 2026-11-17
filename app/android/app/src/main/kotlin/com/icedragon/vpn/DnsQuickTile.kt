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

/** The Quick Settings tile: turns the DNS-only mode on or off without the app. */
class DnsQuickTile : TileService() {
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
            QuickTile.refresh(this)
            return
        }
        if (CoreService.on && CoreService.isDnsOnly) {
            // Already in DNS mode: turning off shuts off both modes.
            CoreService.turnOff(this)
        } else if (CoreService.usesVpn(this) && VpnService.prepare(this) != null) {
            openApp()
        } else {
            try {
                // Starts DNS-only mode (if VPN was active, it stops VPN first).
                CoreService.turnOn(this, dnsOnly = true)
            } catch (e: Exception) {
                Log.w("DnsQuickTile", "starting DNS-only service failed; opening the app", e)
                openApp()
            }
        }
        show()
        QuickTile.refresh(this)
    }

    private fun show() {
        val tile = qsTile ?: return
        tile.state = if (CoreService.on && CoreService.isDnsOnly) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.quick_tile_dns)
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
        /** Asks the system to show the tile's state again. */
        fun refresh(context: Context) {
            TileService.requestListeningState(context, ComponentName(context, DnsQuickTile::class.java))
        }
    }
}
