
extension SwiftDocker {
    static var dockerfileTemplate: String {"""
    # ================================
    # Build image
    # ================================
    FROM {{image}} as build

    WORKDIR /build

    # First just resolve dependencies.
    # This creates a cached layer that can be reused
    # as long as your Package.swift/Package.resolved
    # files do not change.
    COPY ./Package.* ./
    RUN swift package resolve

    # Copy entire repo into container
    COPY . .

    RUN swift {{operation}} {{options}}

    {{#executable}}
    # Switch to the staging area
    WORKDIR /staging

    # Copy main executable to staging area
    RUN cp "$(swift build --package-path /build {{#configuration}}-c {{.}} {{/configuration}}--show-bin-path)/{{executable}}" ./

    # ================================
    # Run image
    # ================================
    FROM {{image}}{{^noSlim}}-slim{{/noSlim}}

    # Create a swiftdocker user and group with /app as its home directory
    RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app swiftdocker

    # Switch to the new home directory
    WORKDIR /app

    # Copy built executable and any staged resources from builder
    COPY --from=build --chown=swiftdocker:swiftdocker /staging /app

    # Ensure all further commands run as the swiftdocker user
    USER swiftdocker:swiftdocker

    # Run the executable when the image is run
    ENTRYPOINT ["./{{executable}}"]
    CMD []

    {{/executable}}

    """}
}
