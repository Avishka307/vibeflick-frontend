import com.android.build.gradle.BaseExtension

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // මේ පේළිය වෙනස් කරන්න
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.avishka.vibeflick.my_vibe_flick"
    compileSdk = 36 // Updated to 36 as required by plugins
    ndkVersion = "29.0.14206865"

    compileOptions {
        // මෙන්න මේ විදිහට වෙනස් කරන්න
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.avishka.vibeflick.my_vibe_flick"
        minSdk = 24
        targetSdk = 36 // Updated to 36 for consistency
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
       // minSdk = flutter.minSdkVersion
        //targetSdk = flutter.targetSdkVersion
        //versionCode = flutter.versionCode
        //versionName = flutter.versionName

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
dependencies {
    // මේ පේළියෙන් libs එකේ තියෙන ෆයිල් එක කෙලින්ම ගන්නවා
// 🚀 මෙන්න මේ ටික අලුතින්ම දාන්න (බලෙන්ම 1.15.0 ගන්න)
    implementation("androidx.core:core:1.15.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity:1.9.3")
    implementation("androidx.activity:activity-ktx:1.9.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }

    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            configure<com.android.build.gradle.BaseExtension> {
                // lStar ප්‍රශ්නය විසඳීමට මෙය අනිවාර්යයි
                compileSdkVersion(34)
                buildToolsVersion("34.0.0")

                defaultConfig {
                    // ප්ලගින් එක ඇතුළෙත් බලෙන්ම SDK 34 සෙට් කරනවා
                    targetSdk = 34
                    multiDexEnabled = true
                }

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
}

// අර Duplicate Error එක එන එක නවත්තන්න මේ කොටසත් පල්ලෙහායින්ම දාන්න
configurations.all {
    resolutionStrategy {
        // ඔයා කලින් දාපු deepar අයින් කරන කෑල්ල
// 🚀 මේක තමයි වැදගත්ම කෑල්ල
        force("androidx.core:core:1.15.0")
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")

        // 🚀 FFmpeg ලෙඩේට අලුතින් දාන්න ඕන කෑල්ල
        eachDependency {
            if (requested.group == "com.arthenica" && requested.name.contains("ffmpeg-kit")) {
                useVersion("6.0")
            }
        }
    }
}
flutter {
    source = "../.."
}
