plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase / Google Services — processes google-services.json (Phase 1.9)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.lifelogger.life_logger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring for java.time APIs on API < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lifelogger.life_logger"
        // Health Connect requires Android 9+ (API 28).
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Ensure native .so files (sqlite3, etc.) are extracted from the APK
    // at install time rather than loaded directly from compressed storage.
    // Required for sqlite3_flutter_libs 0.5.x on AGP 8.x+ where the
    // default behaviour changed to store libs compressed (useLegacyPackaging=false).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for java.time on older APIs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Google Health Connect client (Phase 1.5.2).
    implementation("androidx.health.connect:connect-client:1.1.0-alpha07")

    // Android WorkManager for periodic background sync (Phase 1.5.5).
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Kotlin coroutines (required by Health Connect suspend functions).
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
