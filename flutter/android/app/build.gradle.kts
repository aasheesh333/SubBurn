import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Firebase services must be applied after the Android plugin.
    id("com.google.gms.google-services")
    // Uploads the R8 mapping file so Crashlytics stack traces are readable.
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/// Release signing is read from `android/key.properties`, which is never
/// committed. When it is absent (a clean clone, a fork, a CI run without
/// secrets) the release build falls back to the debug key and prints a warning,
/// so `flutter build apk --release` still works for contributors — but the
/// build that goes to Play must have the real keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
} else {
    logger.warn(
        "WARNING: android/key.properties is missing. Release builds are signed " +
            "with the debug key and cannot be uploaded to Play Console."
    )
}

android {
    namespace = "com.subburn.subburn"
    // flutter_local_notifications 23 and androidx.core 1.19 publish AARs built
    // against API 37, so the app must compile against 37 as well. targetSdk
    // stays at Flutter's default (36) — compiling against a newer SDK does not
    // opt the app into new runtime behaviour.
    compileSdk = 37

    // NDK r27+ is required for 16 KB page-size alignment on Android 15+.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on API < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.subburn.subburn"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Play requires an explicit, stable ABI set; arm64 is mandatory.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // Resolved against `android/`, not `android/app/`. `file()`
                // here is module-relative and looked for the keystore in
                // android/app/keystore, which is not where it lives.
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // v2 is required by Play; v3 enables key rotation.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            // Keep debug builds fast and debuggable; Crashlytics collection is
            // already disabled in Dart for kDebugMode.
            isMinifyEnabled = false
        }
    }

    // 16 KB page size: keep native libraries uncompressed so the linker can
    // 16 KB-align them. Required for Play targeting Android 15+ devices.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/*.kotlin_module",
            )
        }
    }

    bundle {
        // Split by language and density so the download stays small.
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}