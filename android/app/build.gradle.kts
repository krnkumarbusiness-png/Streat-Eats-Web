plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.streeteats.hld"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // ✅ yeh add kiya
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = "street-eats"
            keyPassword = "anjuarya839@#$"
            storeFile = file("../../street-eats-key.jks")
            storePassword = "anjuarya839@#$"
        }
    }

  defaultConfig {
    applicationId = "com.streeteats.hld"
    minSdk = 28              // ✅ Android 9+
    targetSdk = 35           // ✅ Latest
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true   // ✅ ANR fix
}

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")  // ✅ yeh add kiya
}

flutter {
    source = "../.."
}