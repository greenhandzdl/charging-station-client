pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 🌟 1. 优先走国内镜像拉取 Gradle 插件与依赖
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

// 🌟 2. 集中管理应用与依赖库的下载地址（防冲突，且能加速三方原生插件下载）
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // 1. 🌟 新增：国内的 Flutter 引擎镜像源（专门用来加速拉取 arm64_v8a_debug 等引擎包）
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        
        // 2. 阿里云和官方源
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        
        // 3. 🌟 新增：Flutter 官方的默认引擎源（防漏网之鱼）
        maven { url = uri("https://download.flutter.io") }
        
        google()
        mavenCentral()
    }
}

include(":app")