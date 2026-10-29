import java.util.Properties
import groovy.json.JsonSlurper
import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeys = Properties()
val releaseKeysFile = rootProject.file("key.properties")
if (releaseKeysFile.exists()) releaseKeysFile.inputStream().use { releaseKeys.load(it) }
val hasReleaseKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseKeys.getProperty(it).isNullOrBlank() }
val allowTesterSigning = providers.environmentVariable("WHATMEAL_TESTER_SIGNING").orNull == "true"

android {
    namespace = "com.example.whatmeal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "environment"
    productFlavors {
        create("production") { dimension = "environment" }
        create("local") {
            dimension = "environment"
            applicationIdSuffix = ".local"
        }
        create("showcase") {
            dimension = "environment"
            applicationIdSuffix = ".showcase"
        }
        create("aitest") {
            dimension = "environment"
            applicationIdSuffix = ".aitest"
        }
        create("cloudtest") {
            dimension = "environment"
            applicationIdSuffix = ".cloudtest"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.whatmeal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk must be >= 21 for Firebase + flutter_local_notifications desugaring.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKeys -> signingConfigs.getByName("release")
                allowTesterSigning -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

// Exclude forbidden variants before AGP creates shared native build tasks.
// Otherwise a valid showcase release can depend on preCloudtestReleaseBuild
// through configureCMakeRelease and trip the debug-only guard below.
androidComponents {
    beforeVariants(selector().all()) { variant ->
        val isolatedTestFlavor = variant.productFlavors.any {
            it.first == "environment" && it.second in setOf("aitest", "cloudtest")
        }
        if (isolatedTestFlavor && variant.buildType != "debug") {
            variant.enable = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// A release must never silently inherit debug signing. Local tester builds opt in.
tasks.matching { it.name.startsWith("package") && it.name.contains("Release") }.configureEach {
    doFirst {
        check(hasReleaseKeys || allowTesterSigning) {
            "Configure android/key.properties or explicitly set WHATMEAL_TESTER_SIGNING=true for a local tester build."
        }
    }
}

// This separate package must never inherit the normal app's entry point or its
// shared native Firebase configuration. Fail before generating an AI-test APK.
tasks.matching { it.name.contains("aitest", ignoreCase = true) }.configureEach {
    doFirst {
        check(!name.contains("Release", ignoreCase = true) &&
              !name.contains("Profile", ignoreCase = true)) {
            "The approved AI-only harness is debug-only."
        }
        val target = providers.gradleProperty("target").orNull
        check(!target.isNullOrBlank()) {
            "AI testing requires the explicit lib/main_ai_test.dart target."
        }
        val targetFile = File(target!!).let {
            if (it.isAbsolute) it else File(rootProject.projectDir.parentFile, target)
        }
        check(targetFile.canonicalFile == rootProject.file("../lib/main_ai_test.dart").canonicalFile) {
            "AI testing requires the explicit lib/main_ai_test.dart target."
        }
        val nativeConfigFile = file("src/aitest/google-services.json")
        check(nativeConfigFile.isFile) {
            "The approved AI-test native Firebase configuration is missing."
        }
        val config = JsonSlurper().parse(nativeConfigFile) as? Map<*, *>
        val info = config?.get("project_info") as? Map<*, *>
        check(info?.get("project_id") == "whatmeal-gemini-test-20261019" &&
              info?.get("project_number").toString() == "952163528165") {
            "AI-test native Firebase project does not match approval."
        }
        val clients = config?.get("client") as? List<*> ?: emptyList<Any>()
        val approvedClient = clients.filterIsInstance<Map<*, *>>().any { client ->
            val clientInfo = client["client_info"] as? Map<*, *>
            val androidInfo = clientInfo?.get("android_client_info") as? Map<*, *>
            androidInfo?.get("package_name") == "com.example.whatmeal.aitest" &&
                clientInfo?.get("mobilesdk_app_id") == "1:952163528165:android:9348c46aaa5943ff95530c"
        }
        check(approvedClient) {
            "AI-test native Firebase Android app does not match approval."
        }
    }
}

// A full-app cloud acceptance build is also a separate disposable Android app.
// Permit only its normal bootstrap or the reviewed acceptance entry point.
tasks.matching { it.name.contains("cloudtest", ignoreCase = true) }.configureEach {
    doFirst {
        check(!name.contains("Release", ignoreCase = true) &&
              !name.contains("Profile", ignoreCase = true)) {
            "The approved cloud acceptance build is debug-only."
        }
        val target = providers.gradleProperty("target").orNull
        check(!target.isNullOrBlank()) {
            "Cloud testing requires an explicitly approved Dart entry point."
        }
        val targetFile = File(target!!).let {
            if (it.isAbsolute) it else File(rootProject.projectDir.parentFile, target)
        }.canonicalFile
        val approvedTargets = listOf(
            rootProject.file("../lib/main.dart").canonicalFile,
            rootProject.file("../integration_test/cloud_generation_persistence_test.dart").canonicalFile,
        )
        check(targetFile in approvedTargets) {
            "Cloud testing requires an explicitly approved Dart entry point."
        }
        val nativeConfigFile = file("src/cloudtest/google-services.json")
        check(nativeConfigFile.isFile) {
            "The approved cloud-test native Firebase configuration is missing."
        }
        val config = JsonSlurper().parse(nativeConfigFile) as? Map<*, *>
        val info = config?.get("project_info") as? Map<*, *>
        check(info?.get("project_id") == "whatmeal-gemini-test-20261019" &&
              info?.get("project_number").toString() == "952163528165") {
            "Cloud-test native Firebase project does not match approval."
        }
        val clients = config?.get("client") as? List<*> ?: emptyList<Any>()
        val approvedClient = clients.filterIsInstance<Map<*, *>>().any { client ->
            val clientInfo = client["client_info"] as? Map<*, *>
            val androidInfo = clientInfo?.get("android_client_info") as? Map<*, *>
            androidInfo?.get("package_name") == "com.example.whatmeal.cloudtest" &&
                clientInfo?.get("mobilesdk_app_id") == "1:952163528165:android:e184bb528e406cff95530c"
        }
        check(approvedClient) {
            "Cloud-test native Firebase Android app does not match approval."
        }
    }
}
