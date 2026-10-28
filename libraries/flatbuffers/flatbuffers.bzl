load("@rules_swift//swift:swift_library.bzl", "swift_library")

def flatbuffers_swift_library(name, srcs, module_name, visibility = None):
    outs = [src.rsplit("/", 1)[-1].rsplit(".", 1)[0] + "_generated.swift" for src in srcs]

    native.genrule(
        name = name + "Sources",
        srcs = srcs,
        outs = outs,
        tools = ["//libraries/flatbuffers:flatc"],
        cmd = "$(execpath //libraries/flatbuffers:flatc) --swift -I $$(dirname $(rootpath {first})) -o $(RULEDIR) $(SRCS)".format(
            first = srcs[0],
        ),
    )

    swift_library(
        name = name,
        srcs = [":" + name + "Sources"],
        module_name = module_name,
        copts = ["-swift-version", "6"],
        deps = ["//libraries/flatbuffers"],
        visibility = visibility,
    )
