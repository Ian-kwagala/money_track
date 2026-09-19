-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Hive
-keep class com.moneytrack.money_track.models.** { *; }
-keep class * extends hive.TypeAdapter
-keep class * extends hive.HiveObject
-keepclassmembers class * extends hive.HiveObject {
    <fields>;
}
-keep class **.*Adapter { *; }
-dontwarn javax.annotation.**

# Provider
-keep class provider.** { *; }
