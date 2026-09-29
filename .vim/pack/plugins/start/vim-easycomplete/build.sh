#!/usr/bin/env sh

#name="debug"
name="release"

rm -rf ./target/release

if [ "$name" = "debug" ]; then
    ####################### dev #######################
    echo "debug build"

    cargo rustc -- \
      -C link-arg=-undefined \
      -C link-arg=dynamic_lookup \
      -C opt-level=3 \
      --target x86_64-apple-darwin

    cd ./target
    ln -s debug release

else
    ####################### release #######################
    echo "release build"

    rm -rf ./target/debug
    cargo rustc --release -- \
      -C link-arg=-undefined \
      -C link-arg=dynamic_lookup \
      -C opt-level=3 \
      -C debuginfo=0 \
      --target x86_64-apple-darwin

    rm ./target/.rustc_info.json
    rm ./target/release/libeasycomplete_rust_speed.d
    rm ./target/release/.cargo-lock
    rm -rf ./target/release/incremental
    rm -rf ./target/release/examples
    rm -rf ./target/release/deps
    rm -rf ./target/release/build
    rm -rf ./target/release/.fingerprint
fi

echo "dylib created!"
