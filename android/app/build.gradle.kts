plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Apply the Google Services plugin
}

android {
    namespace = "com.ButterflyTchnology.managereceipt" // Use your actual namespace
    compileSdk = 36 // Keep at 35 or higher
    ndkVersion = "27.0.12077973" // Your NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Set to Java 1.8
        targetCompatibility = JavaVersion.VERSION_1_8 // Set to Java 1.8
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString() // Set to Java 1.8
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "om.ButterflyTchnology.managereceipt" // Your actual application ID
        minSdk = 24
        targetSdk = 36 // Keep at 35 or higher
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("release") {
            // Add your release signing config here if you have one
            // For now, using debug keys as per your original file
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release") // Use release signing config
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        disable("InvalidPackage")
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0")
    implementation("androidx.multidex:multidex:2.0.1")
    // Firebase dependencies
    implementation(platform("com.google.firebase:firebase-bom:32.7.0")) // Use a compatible BOM version
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}
