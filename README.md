# swift-docker

Integrate docker into swift command line.

## Basic Usage

Build a Swift project
```
swift docker build
```
Test a Swift project
```
swift docker test
```
Choose the version of Swift you want to build/test with
```
swift docker test -i swift:5.2
```

## Installing

Currently the easiest way to install `swift-docker` is via [mint](https://github.com/yonaskolb/Mint). Once you have mint installed you can install as follows
```
mint install swift-docker
```

## Command line options

| Option | Description |
|---|---|
|-i/--image | Select swift image to use|
|-o/--output| Instead of running docker just output Dockerfile|
|-t/--tag   | Tag docker output with tag|

By adding a `--` everything else after that in the command line will be added as an option to the swift test/build command in the docker file.
```
swift docker test -- --enable-test-discovery
```
