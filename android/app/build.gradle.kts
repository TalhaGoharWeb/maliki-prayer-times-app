import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.talhagohar.malikiprayertimes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (uses java.time APIs).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.talhagohar.malikiprayertimes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Production signing: reads android/key.properties (git-ignored, never
    // committed). Falls back to the pinned TEST key when absent so any
    // checkout still builds installable test APKs.
    val keystorePropsFile = rootProject.file("key.properties")
    val keystoreProps = Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(FileInputStream(keystorePropsFile))
    }

    signingConfigs {
        // TEST ONLY keystore (android/test-key.keystore, credentials "android").
        // It exists so every test APK I build carries the SAME signature and
        // installs as an update over the previous test build. The sandbox's
        // auto-generated debug keystore does not survive VM replacements,
        // which caused "package conflicts with an existing package" install
        // failures. NEVER use this key for a production/Play release.
        create("testkey") {
            storeFile = file("../test-key.keystore")
            storePassword = "android"
            keyAlias = "testkey"
            keyPassword = "android"
        }
        if (keystorePropsFile.exists()) {
            create("prodkey") {
                storeFile = file("../${keystoreProps["storeFile"]}")
                storePassword = keystoreProps["storePassword"] as String
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Production key when key.properties exists, test key otherwise.
            signingConfig = if (keystorePropsFile.exists()) {
                signingConfigs.getByName("prodkey")
            } else {
                signingConfigs.getByName("testkey")
            }
            // Resource shrinking is OFF: the adhan recording
            // (res/raw/tunisi_adhan.mp3) is referenced only by name string
            // from Dart (RawResourceAndroidNotificationSound), which the
            // R8-driven resource shrinker cannot trace. tools:keep in
            // res/values/keep.xml was verified NOT to protect it (the raw
            // entry was present in the linked .ap_ but stripped from the
            // shrunk .ap_), so shrinking stays disabled to keep the adhan
            // reliably in the APK. Code shrinking (R8) remains enabled.
            isShrinkResources = false
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

dependencies {
    // Core library desugaring (flutter_local_notifications requirement).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Align androidx.activity artifacts: package_info_plus / url_launcher pull
// newer activity versions than other plugins' activity-ktx; misaligned pairs
// fail checkReleaseDuplicateClasses (duplicate ActivityViewModelLazyKt).
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity:1.9.0")
        force("androidx.activity:activity-ktx:1.9.0")
    }
}
