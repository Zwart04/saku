package id.zwart.saku

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val nativePrefs by lazy { getSharedPreferences("saku_native", Context.MODE_PRIVATE) }
    private var pendingPick: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_FOLDER) {
            var ok = false
            val uri = data?.data
            if (uri != null) {
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    nativePrefs.edit().putString(KEY_TREE, uri.toString()).apply()
                    ensureDefaultFiles()
                    ok = true
                } catch (t: Throwable) {
                    ok = false
                }
            }
            pendingPick?.success(ok)
            pendingPick = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CHANNEL_FOLDER).setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    pendingPick = result
                    try {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQUEST_PICK_FOLDER)
                    } catch (t: Throwable) {
                        pendingPick?.success(false)
                        pendingPick = null
                    }
                }
                "name" -> result.success(treeUri()?.let { DocumentsContract.getTreeDocumentId(it) })
                "ready" -> result.success(folderReady())
                "ensure" -> {
                    ensureDefaultFiles()
                    result.success(folderReady())
                }
                "read" -> result.success(readFile(call.argument<String>("name") ?: ""))
                "write" -> result.success(
                    writeFile(
                        call.argument<String>("name") ?: "",
                        call.argument<String>("content") ?: ""
                    )
                )
                "exists" -> result.success(fileExists(call.argument<String>("name") ?: ""))
                "appendCsv" -> result.success(
                    appendCsv(
                        call.argument<String>("name") ?: "",
                        call.argument<String>("content") ?: ""
                    )
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, CHANNEL_APPS).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> result.success(listInstalledApps())
                "notifAccess" -> result.success(notifAccessGranted())
                "openNotifSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "testNotif" -> {
                    val sent = sendTestNotification()
                    result.success(sent)
                }
                "getWhitelist" -> result.success(getWhitelist().toList())
                "setWhitelist" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    nativePrefs.edit().putStringSet(KEY_WHITELIST, packages.toSet()).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, CHANNEL_WIDGET).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val total = call.argument<Int>("totalToday") ?: 0
                    nativePrefs.edit().putInt(KEY_WIDGET_TOTAL, total).apply()
                    SakuWidgetProvider.updateAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, CHANNEL_NOTIFS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                SakuNotifBridge.sink = events
                SakuNotifBridge.flushBuffered()
            }

            override fun onCancel(args: Any?) {
                SakuNotifBridge.sink = null
            }
        })
    }

    // ---------- folder SAF ----------

    private fun treeUri(): Uri? = nativePrefs.getString(KEY_TREE, null)?.let { Uri.parse(it) }

    private fun rootDoc(tree: Uri): Uri? = try {
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
    } catch (t: Throwable) {
        null
    }

    private fun childFiles(root: Uri): List<Pair<String, Uri>> {
        val out = ArrayList<Pair<String, Uri>>()
        val rootId = try {
            DocumentsContract.getDocumentId(root)
        } catch (t: Throwable) {
            return out
        }
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(root, rootId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        return try {
            contentResolver.query(children, projection, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val name = c.getString(1) ?: continue
                    val mime = c.getString(2)
                    if (mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        out.add(name to DocumentsContract.buildDocumentUriUsingTree(root, id))
                    }
                }
            }
            out
        } catch (t: Throwable) {
            out
        }
    }

    private fun folderReady(): Boolean {
        val tree = treeUri() ?: return false
        val root = rootDoc(tree) ?: return false
        return try {
            contentResolver.query(
                root,
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null, null, null
            ) != null
        } catch (t: Throwable) {
            false
        }
    }

    private fun fileExists(name: String): Boolean {
        val tree = treeUri() ?: return false
        val root = rootDoc(tree) ?: return false
        return childFiles(root).any { it.first == name }
    }

    private fun writeFile(name: String, content: String): Boolean {
        val tree = treeUri() ?: return false
        val root = rootDoc(tree) ?: return false
        val existing = childFiles(root).firstOrNull { it.first == name }?.second
        val fileUri = existing
            ?: DocumentsContract.createDocument(contentResolver, root, "application/json", name)
            ?: return false
        return try {
            contentResolver.openOutputStream(fileUri, "wt")?.use {
                it.write(content.toByteArray(Charsets.UTF_8))
                true
            } ?: false
        } catch (t: Throwable) {
            false
        }
    }

    private fun readFile(name: String): String? {
        val tree = treeUri() ?: return null
        val root = rootDoc(tree) ?: return null
        val fileUri = childFiles(root).firstOrNull { it.first == name }?.second ?: return null
        return try {
            contentResolver.openInputStream(fileUri)?.bufferedReader()?.use { it.readText() }
        } catch (t: Throwable) {
            null
        }
    }

    private fun appendCsv(name: String, content: String): Boolean {
        val tree = treeUri() ?: return false
        val root = rootDoc(tree) ?: return false
        val existing = childFiles(root).firstOrNull { it.first == name }?.second
        val fileUri = existing
            ?: DocumentsContract.createDocument(contentResolver, root, "text/csv", name)
            ?: return false
        val mode = if (existing != null) "wa" else "wt"
        return try {
            contentResolver.openOutputStream(fileUri, mode)?.use {
                it.write((content + "\n").toByteArray(Charsets.UTF_8))
                true
            } ?: false
        } catch (t: Throwable) {
            false
        }
    }

    private fun ensureDefaultFiles() {
        if (!folderReady()) return
        if (!fileExists("expenses.json")) writeFile("expenses.json", "[]")
        if (!fileExists("pending.json")) writeFile("pending.json", "[]")
        if (!fileExists("dashboard.json")) writeFile("dashboard.json", "[]")
    }

    // ---------- apps ----------

    private fun listInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = ArrayList<Map<String, String>>()
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = try {
            pm.queryIntentActivities(main, 0)
        } catch (t: Throwable) {
            emptyList()
        }
        for (info in resolved) {
            val pkg = info.activityInfo?.applicationInfo?.packageName ?: continue
            val label = try {
                info.activityInfo.applicationInfo.loadLabel(pm).toString()
            } catch (t: Throwable) {
                pkg
            }
            apps.add(mapOf("package" to pkg, "label" to label))
        }
        return apps
    }

    private fun notifAccessGranted(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    private fun getWhitelist(): Set<String> =
        nativePrefs.getStringSet(KEY_WHITELIST, emptySet()) ?: emptySet()

    private fun sendTestNotification(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, "android.permission.POST_NOTIFICATIONS") !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf("android.permission.POST_NOTIFICATIONS"),
                4242
            )
            return false
        }
        val nm = NotificationManagerCompat.from(this)
        val channelId = "saku_test"
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Saku uji", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        val notif = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle("Uji Saku")
            .setContentText("Kamu menerima Rp25.000 dari GoPay")
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        return try {
            nm.notify(1901, notif)
            true
        } catch (t: Throwable) {
            false
        }
    }

    companion object {
        const val CHANNEL_FOLDER = "saku/folder"
        const val CHANNEL_APPS = "saku/apps"
        const val CHANNEL_WIDGET = "saku/widget"
        const val CHANNEL_NOTIFS = "saku/notifs"
        const val KEY_TREE = "tree_uri"
        const val KEY_WHITELIST = "notif_whitelist"
        const val KEY_WIDGET_TOTAL = "widget_total_today"
        const val REQUEST_PICK_FOLDER = 4243
    }
}
