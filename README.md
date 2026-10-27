# Airlance

Clone the repository and download all pinned library submodules in one step:

```sh
git clone --recurse-submodules https://github.com/resoul/Airlance.git
```

If you already cloned the repository without its submodules, initialize and download them from the Airlance root directory:

```sh
git submodule update --init --recursive
```

The codec sources are checked out under `libraries/<name>/<name>` at the
commits recorded by this repository. Other dependencies, such as GRDB, are
downloaded separately by Bazel when needed. To inspect the submodule checkouts:

```sh
git submodule status --recursive
```
