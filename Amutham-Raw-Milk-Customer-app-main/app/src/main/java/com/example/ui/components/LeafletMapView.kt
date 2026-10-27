package com.example.ui.components

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView

import android.view.View
import android.webkit.RenderProcessGoneDetail

class MapBridge(
    private val onLocationSelected: (Double, Double) -> Unit
) {
    @JavascriptInterface
    fun onPinMoved(lat: Double, lng: Double) {
        onLocationSelected(lat, lng)
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun LeafletMapView(
    latitude: Double,
    longitude: Double,
    modifier: Modifier = Modifier,
    isPickerMode: Boolean = false,
    deliveryPersonLat: Double? = null,
    deliveryPersonLng: Double? = null,
    deliveryPersonName: String? = null,
    onLocationChanged: ((Double, Double) -> Unit)? = null
) {
    val context = LocalContext.current

    val htmlContent = remember(latitude, longitude, isPickerMode, deliveryPersonLat, deliveryPersonLng) {
        generateLeafletHtml(
            lat = latitude,
            lng = longitude,
            isPicker = isPickerMode,
            agentLat = deliveryPersonLat,
            agentLng = deliveryPersonLng,
            agentName = deliveryPersonName ?: "Delivery Agent"
        )
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
    ) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                WebView(ctx).apply {
                    // Set software layer type to avoid Mesa /dev/dri/renderD128 hardware render node missing errors
                    setLayerType(View.LAYER_TYPE_SOFTWARE, null)
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.cacheMode = WebSettings.LOAD_DEFAULT
                    settings.allowFileAccess = false
                    settings.allowContentAccess = false
                    webViewClient = object : WebViewClient() {
                        override fun onRenderProcessGone(
                            view: WebView?,
                            detail: RenderProcessGoneDetail?
                        ): Boolean {
                            // Gracefully handle render process termination without crashing
                            return true
                        }
                    }
                    if (onLocationChanged != null) {
                        addJavascriptInterface(MapBridge(onLocationChanged), "AndroidMapBridge")
                    }
                    loadDataWithBaseURL("https://openstreetmap.org", htmlContent, "text/html", "UTF-8", null)
                }
            },
            update = { webView ->
                webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
                webView.loadDataWithBaseURL("https://openstreetmap.org", htmlContent, "text/html", "UTF-8", null)
            }
        )

        // Overlay info bar
        Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(8.dp),
            shape = RoundedCornerShape(10.dp),
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
            shadowElevation = 3.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isPickerMode) "Tap map or drag marker to set delivery spot" else "Delivery Coordinates",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Lat: ${"%.4f".format(latitude)}, Lng: ${"%.4f".format(longitude)}",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                if (isPickerMode) {
                    Text(
                        text = "Interactive",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(4.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }
        }
    }
}

private fun generateLeafletHtml(
    lat: Double,
    lng: Double,
    isPicker: Boolean,
    agentLat: Double?,
    agentLng: Double?,
    agentName: String
): String {
    val hasAgent = agentLat != null && agentLng != null
    return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no" />
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>
                html, body, #map {
                    width: 100%;
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    background-color: #e5e3df;
                }
                .custom-customer-pin {
                    background-color: #059669;
                    color: white;
                    border: 2px solid white;
                    border-radius: 50%;
                    text-align: center;
                    font-weight: bold;
                    line-height: 28px;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
                }
                .custom-agent-pin {
                    background-color: #10B981;
                    color: white;
                    border: 2px solid white;
                    border-radius: 50%;
                    text-align: center;
                    font-weight: bold;
                    line-height: 28px;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
                }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                var map = L.map('map', {
                    zoomControl: false,
                    attributionControl: false
                }).setView([$lat, $lng], 15);

                L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19
                }).addTo(map);

                var customerIcon = L.divIcon({
                    className: 'custom-customer-pin',
                    html: '🏠',
                    iconSize: [32, 32],
                    iconAnchor: [16, 16]
                });

                var customerMarker = L.marker([$lat, $lng], {
                    draggable: ${if (isPicker) "true" else "false"},
                    icon: customerIcon
                }).addTo(map);

                customerMarker.bindPopup('<b>Customer Delivery Location</b><br>Fresh milk dropped here.').openPopup();

                ${if (isPicker) """
                    customerMarker.on('dragend', function(e) {
                        var position = customerMarker.getLatLng();
                        if (window.AndroidMapBridge) {
                            window.AndroidMapBridge.onPinMoved(position.lat, position.lng);
                        }
                    });

                    map.on('click', function(e) {
                        customerMarker.setLatLng(e.latlng);
                        if (window.AndroidMapBridge) {
                            window.AndroidMapBridge.onPinMoved(e.latlng.lat, e.latlng.lng);
                        }
                    });
                """ else ""}

                ${if (hasAgent) """
                    var agentIcon = L.divIcon({
                        className: 'custom-agent-pin',
                        html: '🥛',
                        iconSize: [34, 34],
                        iconAnchor: [17, 17]
                    });

                    var agentMarker = L.marker([$agentLat, $agentLng], {
                        icon: agentIcon
                    }).addTo(map);

                    agentMarker.bindPopup('<b>$agentName</b><br>Currently out for delivery');

                    var routeLine = L.polyline([
                        [$agentLat, $agentLng],
                        [$lat, $lng]
                    ], {
                        color: '#059669',
                        weight: 4,
                        opacity: 0.8,
                        dashArray: '6, 8'
                    }).addTo(map);

                    var group = new L.featureGroup([customerMarker, agentMarker]);
                    map.fitBounds(group.pad(0.3));
                """ else ""}
            </script>
        </body>
        </html>
    """.trimIndent()
}
