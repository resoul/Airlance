load("@rules_swift//swift:swift_library.bzl", "swift_library")

swift_library(
    name = "flatbuffers",
    srcs = ["@flatbuffers_swift_sources//:swift_sources"],
    module_name = "FlatBuffers",
    copts = ["-swift-version", "6"],
    visibility = ["//visibility:public"],
)

alias(
    name = "flatc",
    actual = "@flatbuffers_sources//:flatc",
    visibility = ["//visibility:public"],
)
