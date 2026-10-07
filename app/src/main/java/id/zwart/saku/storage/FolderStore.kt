package id.zwart.saku.storage

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract

/**
 * Penyimpanan data di folder bersama yang dipilih pengguna lewat SAF (folder picker).
 * File di folder ini TIDAK ikut terhapus saat aplikasi dibongkar (uninstall),
 * jadi data dan dashboard bisa dipulihkan setelah install ulang dengan memilih
 * folder yang sama.
 */
class FolderStore(private val context: Context) {

    private val settings = context.getSharedPreferences("zwart_money_agent", Context.MODE_PRIVATE)

    val treeUri: Uri?
        get() = settings.getString(KEY_TREE, null)?.let { Uri.parse(it) }

    fun setTreeUri(uri: Uri) {
        settings.edit().putString(KEY_TREE, uri.toString()).apply()
    }

    fun isReady(): Boolean {
        val tree = treeUri ?: return false
        val root = rootDoc(tree) ?: return false
        return try {
            context.contentResolver.query(
                root,
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null,
                null,
                null
            ) != null
        } catch (t: Throwable) {
            false
        }
    }

    fun takePersistablePermission(uri: Uri) {
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (t: Throwable) {
            // izin sudah ada atau folder berubah — abaikan
        }
    }

    fun write(name: String, content: String): Boolean {
        val tree = treeUri ?: return false
        val root = rootDoc(tree) ?: return false
        val existing = childFiles(root).firstOrNull { it.first == name }?.second
        val fileUri = existing
            ?: DocumentsContract.createDocument(context.contentResolver, root, "application/json", name)
            ?: return false
        return try {
            context.contentResolver.openOutputStream(fileUri, "wt")?.use { out ->
                out.write(content.toByteArray(Charsets.UTF_8))
                true
            } ?: false
        } catch (t: Throwable) {
            false
        }
    }

    fun read(name: String): String? {
        val tree = treeUri ?: return null
        val root = rootDoc(tree) ?: return null
        val fileUri = childFiles(root).firstOrNull { it.first == name }?.second ?: return null
        return try {
            context.contentResolver.openInputStream(fileUri)?.bufferedReader()?.use { it.readText() }
        } catch (t: Throwable) {
            null
        }
    }

    fun exists(name: String): Boolean {
        val tree = treeUri ?: return false
        val root = rootDoc(tree) ?: return false
        return childFiles(root).any { it.first == name }
    }

    fun appendToCsv(name: String, line: String): Boolean {
        val tree = treeUri ?: return false
        val root = rootDoc(tree) ?: return false
        val existing = childFiles(root).firstOrNull { it.first == name }?.second
        val fileUri = existing
            ?: DocumentsContract.createDocument(context.contentResolver, root, "text/csv", name)
            ?: return false
        val mode = if (existing != null) "wa" else "wt"
        return try {
            context.contentResolver.openOutputStream(fileUri, mode)?.use { out ->
                out.write((line + "\n").toByteArray(Charsets.UTF_8))
                true
            } ?: false
        } catch (t: Throwable) {
            false
        }
    }

    private fun rootDoc(tree: Uri): Uri? = try {
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
    } catch (t: Throwable) {
        null
    }

    private fun childFiles(root: Uri): List<Pair<String, Uri>> {
        val result = ArrayList<Pair<String, Uri>>()
        val children = try {
            DocumentsContract.buildChildDocumentsUriUsingTree(root, DocumentsContract.getDocumentId(root))
        } catch (t: Throwable) {
            return result
        }
        return try {
            context.contentResolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                ),
                null,
                null,
                null
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val displayName = c.getString(1) ?: continue
                    val mime = c.getString(2)
                    if (mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        result.add(displayName to DocumentsContract.buildDocumentUriUsingTree(root, id))
                    }
                }
            }
            result
        } catch (t: Throwable) {
            result
        }
    }

    companion object {
        private const val KEY_TREE = "tree_uri"

        const val EXPENSES_FILE = "expenses.json"
        const val PENDING_FILE = "pending.json"
        const val DASHBOARD_FILE = "dashboard.json"
        const val EXPORT_FILE = "money_agent_export.csv"
    }
}
