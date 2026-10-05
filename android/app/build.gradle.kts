import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 값은 환경변수가 우선이고, 없으면 저장소 루트의 .keystore/release-signing.properties(커밋 금지)를 읽는다.
val localSigningProperties = Properties().apply {
    val file = rootProject.file("../.keystore/release-signing.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(envName: String, propertyName: String): String? =
    System.getenv(envName) ?: localSigningProperties.getProperty(propertyName)

val releaseStorePassword = signingValue("STORE_PASSWORD", "storePassword")
val hasReleaseSigning = releaseStorePassword != null

android {
    namespace = "com.jeiel85.myfarm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jeiel85.myfarm"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val keystorePath = signingValue("KEYSTORE_PATH", "keystorePath")
                    ?: "../.keystore/my-farm-upload.jks"
                storeFile = rootProject.file(keystorePath)
                storePassword = releaseStorePassword
                keyAlias = signingValue("KEY_ALIAS", "keyAlias") ?: "my-farm"
                keyPassword = signingValue("KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// 서명 정보 없이 릴리스를 만들면 디버그 키로 조용히 대체하지 않고 빌드를 멈춘다.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (buildsRelease && !hasReleaseSigning) {
        throw GradleException(
            "릴리스 서명 정보가 없습니다. .keystore/release-signing.properties 또는 " +
                "STORE_PASSWORD/KEY_PASSWORD/KEYSTORE_PATH 환경변수를 설정하세요."
        )
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
