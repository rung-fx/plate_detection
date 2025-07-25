plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.plate_detection"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.plate_detection"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        buildTypes {
            getByName("release") {
                isMinifyEnabled = true
                isShrinkResources = false
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
                )
                // ใช้ debug key แทน ถ้ายังไม่ได้ทำ signingConfig จริง
                signingConfig = signingConfigs.getByName("debug")
            }

            getByName("debug") {
                isMinifyEnabled = false
            }
        }
    }
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite-gpu:2.12.0")
}

flutter {
    source = "../.."
}
