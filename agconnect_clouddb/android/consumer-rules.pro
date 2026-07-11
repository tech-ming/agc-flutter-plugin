# ==============================================================
# CloudDB ObjectType 混淆保护（consumer rules）
# ==============================================================
# 本文件随 agconnect_clouddb 的 AAR 一起分发，集成方 App 开启 minify
# （isMinifyEnabled=true）时会自动合并应用，集成方无需手动配置。
#
# 背景：
#   CloudDB 的 ObjectType 由官方 ObjectType compiler 生成，继承
#   com.huawei.agconnect.cloud.database.CloudDBZoneObject，SDK 通过反射
#   按“类名 + 字段名”完成对象序列化与云端 schema 映射；一旦 release
#   混淆将其重命名，序列化与 schema 匹配即会失败。
#
# 说明：
#   生成类通常位于包 com.huawei.agconnectclouddb.objecttypes.**，该包不被
#   -keep class com.huawei.agconnect.** 覆盖（agconnect 后需紧跟 .），因此
#   这里按“基类”保留 —— 与集成方实际生成包名无关，最通用。
-keep class * extends com.huawei.agconnect.cloud.database.CloudDBZoneObject { *; }
