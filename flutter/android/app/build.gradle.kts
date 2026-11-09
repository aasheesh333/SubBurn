plugins {
    id("com.android.application")
    // Firebase services must be applied after the Android plugin.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.subburn.subburn"
    compileSdk = flutter.compileSdkVersion

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
    }

    buildTypes {
        release {
            // Debug signing keeps `flutter build apk --release` working out of
            // the box. Swap in the upload keystore before the first Play upload.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // 16 KB page size: keep native libraries uncompressed so the linker can
    // 16 KB-align them. Required for Play targeting Android 15+ devices.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    // Flutter ships every ABI by default in a universal APK; the app bundle
    // handles splits, so nothing extra is needed here.
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
