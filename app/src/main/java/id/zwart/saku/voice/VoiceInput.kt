package id.zwart.saku.voice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * Input suara via SpeechRecognizer Android (dipakai dengan bahasa id-ID).
 * Bisa offline kalau engine SpeechRecognizer pada HP mendukung offline.
 */
class VoiceInput(private val context: Context) {

    private var recognizer: SpeechRecognizer? = null

    fun isAvailable(): Boolean = SpeechRecognizer.isRecognitionAvailable(context)

    fun start(onResult: (String) -> Unit, onError: (String) -> Unit) {
        if (!isAvailable()) {
            onError("Voice recognition tidak tersedia di HP ini.")
            return
        }
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                    .orEmpty()
                if (text.isBlank()) onError("Suaraku tidak terdengar, coba lagi ya.")
                else onResult(text)
            }

            override fun onError(error: Int) {
                onError(when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH -> "Suaraku tidak terdengar, coba lagi ya."
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Suaraku tidak terdengar, coba lagi ya."
                    SpeechRecognizer.ERROR_AUDIO -> "Masalah di mikrofon, coba cek izinnya ya."
                    else -> "Voice error ($error)"
                })
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.forLanguageTag("id-ID").toString())
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "id-ID")
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }
        try {
            recognizer?.startListening(intent)
        } catch (t: Throwable) {
            onError("Voice engine gagal jalan: ${t.message}")
        }
    }

    fun stop() {
        try {
            recognizer?.stopListening()
        } catch (t: Throwable) {
        }
    }

    fun destroy() {
        recognizer?.destroy()
        recognizer = null
    }
}
