#!/bin/bash

set -e -o pipefail -u

if [ "$(uname)" = Darwin ]; then
	HOST_TAG=darwin-x86
	SKIP_HOSTS='linux|mingw|windows'
else
	HOST_TAG=linux-x86
	SKIP_HOSTS='darwin|mingw|windows'
fi

# Fetch source
mkdir -p ~/bin
export PATH=~/bin:$PATH
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
if [ "${CI-false}" = true ]; then
	git config --global user.name "Your Name"
	git config --global user.email "you@example.com"
	git config --global color.ui false
fi
mkdir -p llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest
# Modified the manifest xml, to ensure only contain current host components
sed -E "s/(^.*($SKIP_HOSTS).*$)/<!-- \\1 -->/g" ../manifest_16134705.xml > .repo/manifests/test.xml
repo init -m test.xml
repo sync -c

# Remove older version prebuilts
rm -rf $(find prebuilts/clang/host/$HOST_TAG/clang* -maxdepth 0 | grep -v "clang-r563880" | grep -v "clang-stable")

# Patch to build mlir
patch -p1 < ../build-mlir.patch

# Build
pushd toolchain/llvm_android
python3 build.py --no-build lldb,windows --no-musl --bootstrap-use-prebuilt --skip-tests --skip-runtimes
popd

# Drop intermediate build trees; only these three get packaged
find out -mindepth 1 -maxdepth 1 ! -name install ! -name llvm-project ! -name stage2-install -exec rm -rf {} +
rm -rf prebuilts .repo

tar -cjf package-install.tar.bz2 out/install
tar -cjf package-llvm-project.tar.bz2 out/llvm-project
tar -cjf package-stage2-install.tar.bz2 out/stage2-install

mkdir -p ../output
mv *.tar.bz2 ../output/
