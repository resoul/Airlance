# Airlance

The iOS app of the Airlance messenger, written in Swift 6 and built with Bazel.

It has chats with text, media, voice and video messages, groups and channels, stories with a built-in editor, calls, a custom camera,
an in-app browser, themes and eight languages. Several accounts can live on one device, each with its own encrypted database.

People sign in through [airlance-auth](https://github.com/resoul/auth) with an emailed code and a passkey, and the app talks to
[airlance-server](https://github.com/resoul/airlance-server) over an encrypted WebSocket. So far only the profile comes from the server:
chats and the rest of the content are local fixtures.

## Getting the code

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
