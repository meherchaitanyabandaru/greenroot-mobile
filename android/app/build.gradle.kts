import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Play upload key). Either android/key.properties (git-ignored):
//   storeFile=/path/to/upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// or, in CI, GREENROOT_KEYSTORE_FILE / _PASSWORD / _KEY_ALIAS / _KEY_PASSWORD.
// A release build without either fails: Play refuses debug-signed uploads, and
// a changed signing key would stop updates reaching installed apps.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun signingValue(property: String, env: String): String? =
    keystoreProperties.getProperty(property) ?: System.getenv(env)

val releaseStoreFile = signingValue("storeFile", "GREENROOT_KEYSTORE_FILE")

android {
    namespace = "in.greenroot.greenroot_mobile"
    compileSdk = 37 // permission_handler_android 14.1 requires 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent: the Play Store identifies the app by it.
        applicationId = "in.greenroot.greenroot_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFile != null) {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "GREENROOT_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "GREENROOT_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "GREENROOT_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

gradle.taskGraph.whenReady {
    val releaseTask = allTasks.any { it.name.contains("Release") && (it.name.startsWith("assemble") || it.name.startsWith("bundle")) }
    if (releaseTask && releaseStoreFile == null) {
        throw GradleException(
            "Release builds need the upload keystore: create android/key.properties " +
                "(see android/app/build.gradle.kts) or set GREENROOT_KEYSTORE_FILE and friends."
        )
    }
}
