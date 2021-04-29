# swift-docker

Integrate docker into swift command line.

## Basic Usage

Build a Swift project in docker
```
swift docker build
```
Test a Swift project
```
swift docker test
```
Run a Swift project
```
swift docker run
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
| -i/--image | Select swift image to use |
| -n/--no-slim | swift-docker will automatically use a slim version of a docker image. This option disables this. |
| -o/--output | Instead of running docker just output Dockerfile |
| -t/--tag | Tag docker output with tag |
| -c/--configuration | Set build configuration (debug or release) |
| --product | Set product to build |
| --target | Set target to build |

By adding a `--` everything else after that in the command line will be added as an option to the swift test/build command in the docker file.
```
swift docker test --  --sanitize=thread
```

## Dockerfile Template

It is not possible to create a Dockerfile template that supports all projects. Because of this there is an option to edit the template file used to create the Dockerfile. The following will save a local copy of the template file and open it up into a text editor for you to edit.  
```
swift docker edit
```
