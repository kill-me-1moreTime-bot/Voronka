import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Постоянный ключ подписи: одним ключом подписаны все сборки, поэтому
// новая версия ставится поверх старой и настройки на телефоне остаются.
// Откуда берётся (сам ключ в репозиторий не кладём — он публичный):
// 1) android/key.properties (в .gitignore) — для сборки на компьютере;
// 2) переменные окружения SKAZKI_KEYSTORE… — для GitHub Actions.
// Нет ни того, ни другого — подпись отладочным ключом, как раньше.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun keyValue(prop: String, env: String): String? =
    keyProps.getProperty(prop) ?: System.getenv(env)
val keystorePath = keyValue("storeFile", "SKAZKI_KEYSTORE")
val hasStableKey = keystorePath != null && file(keystorePath).exists()

android {
    namespace = "ru.skazki.skazochnye_druzya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ru.skazki.skazochnye_druzya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasStableKey) {
            create("stable") {
                storeFile = file(keystorePath!!)
                storePassword = keyValue("storePassword", "SKAZKI_STORE_PASSWORD")
                keyAlias = keyValue("keyAlias", "SKAZKI_KEY_ALIAS")
                keyPassword = keyValue("keyPassword", "SKAZKI_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasStableKey) "stable" else "debug")
        }
        debug {
            if (hasStableKey) signingConfig = signingConfigs.getByName("stable")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
