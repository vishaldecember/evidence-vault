plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.evidence_vault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // AGP 8+/9 do not generate BuildConfig unless opted in. EvLog.kt
    // gates debug logging on the app-module BuildConfig.DEBUG field.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // Bound to the Firebase Android app in google-services.json /
        // firebase_options.dart. Do not change without registering a new
        // Android app in Firebase Console and replacing google-services.json.
        applicationId = "com.example.evidence_vault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth requires API 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isDebuggable = false
            // NOT a production signing config. Debug keys let `flutter run
            // --release` work locally. Do not distribute this APK. Add a
            // release keystore via env/local properties — never commit secrets.
            signingConfig = signingConfigs.getByName("debug")
            // R8/minify deferred: requires a dedicated ProGuard pass for
            // Firebase/Flutter plugins before it is safe to enable.
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
