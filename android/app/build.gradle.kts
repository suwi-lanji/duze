import java.util.Properties
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    } else {
        error("key.properties file not found at ${keystorePropertiesFile.absolutePath}")
    }
}
android {
    namespace = "com.codenamegoon.duze"
     compileSdk = 35 // Match Flutter’s typical compileSdk
    ndkVersion = "29.0.13113456"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codenamegoon.duze"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        register("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: error("keyAlias not set in key.properties")
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: error("keyPassword not set in key.properties")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) } ?: error("storeFile not set in key.properties")
            storePassword = keystoreProperties.getProperty("storePassword") ?: error("storePassword not set in key.properties")
        }
        
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    buildTypes {
         debug {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.firebase:firebase-appcheck-playintegrity:17.1.2")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.android.gms:play-services-ads:23.2.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.fragment:fragment-ktx:1.6.2") // For compatibility
    implementation("androidx.activity:activity-ktx:1.8.0") 
    implementation("com.facebook.android:facebook-android-sdk:latest.release")
    implementation("androidx.multidex:multidex:2.0.1")
    

}

flutter {
    source = "../.."
}
