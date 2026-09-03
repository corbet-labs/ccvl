#!/usr/bin/env bash

# Values are consumed by scripts that source this file.
# shellcheck disable=SC2034

CCVL_TYPST_VERSION=0.15.1
CCVL_TYPSTYLE_VERSION=0.15.1
CCVL_JUST_VERSION=1.58.0

ccvl_select_tool_assets() {
  case "$1" in
    Linux-x86_64)
      CCVL_TYPST_ASSET=typst-x86_64-unknown-linux-musl.tar.xz
      CCVL_TYPST_SHA256=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
      CCVL_TYPSTYLE_ASSET=typstyle-x86_64-unknown-linux-gnu
      CCVL_TYPSTYLE_SHA256=213c11bc2c64f7237c382b4bb1d06991530ed9d44d3a05204ca3c19615d55b99
      CCVL_JUST_ASSET=just-1.58.0-x86_64-unknown-linux-musl.tar.gz
      CCVL_JUST_SHA256=4a5cc2f53e6f0f8c59092a6cc38291eb729d46a7dd95d3ae582008881b84931d
      ;;
    Linux-aarch64)
      CCVL_TYPST_ASSET=typst-aarch64-unknown-linux-musl.tar.xz
      CCVL_TYPST_SHA256=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee
      CCVL_TYPSTYLE_ASSET=typstyle-aarch64-unknown-linux-gnu
      CCVL_TYPSTYLE_SHA256=2e7bff51079d2f1faaf8629972e79c3d51a3deeaf9b16386ea83334b94773ad1
      CCVL_JUST_ASSET=just-1.58.0-aarch64-unknown-linux-musl.tar.gz
      CCVL_JUST_SHA256=748237128c4c40cbdabc65e841d05ceba13cc23a91eaba395495894c1d9764df
      ;;
    Darwin-x86_64)
      CCVL_TYPST_ASSET=typst-x86_64-apple-darwin.tar.xz
      CCVL_TYPST_SHA256=7f9fdd9584866245de9a79e0add8f9236fae6f40a8a45e2c4771ccc14db4e0fa
      CCVL_TYPSTYLE_ASSET=typstyle-x86_64-apple-darwin
      CCVL_TYPSTYLE_SHA256=d24debaf653664c64622871df68239d92841261c5c894034120f4a6a74c943ab
      CCVL_JUST_ASSET=just-1.58.0-x86_64-apple-darwin.tar.gz
      CCVL_JUST_SHA256=9a09cfef66aaa79da58203970103a0684307716caaabd3e9844cacc4dc0f4023
      ;;
    Darwin-aarch64)
      CCVL_TYPST_ASSET=typst-aarch64-apple-darwin.tar.xz
      CCVL_TYPST_SHA256=48f62ed034aa3a7978309579ac6ca00045e2ef0da73114e8af27cfd8e74dc05a
      CCVL_TYPSTYLE_ASSET=typstyle-aarch64-apple-darwin
      CCVL_TYPSTYLE_SHA256=f97b74f3a3dfb43ece4e627753d2dae703af2b77f114fb0f1e766f7f1bad5fa1
      CCVL_JUST_ASSET=just-1.58.0-aarch64-apple-darwin.tar.gz
      CCVL_JUST_SHA256=50ae3e996c974a0bf32ea7d10f495070df33f1b43e0616b2769e3d4821ed8f48
      ;;
    *)
      return 1
      ;;
  esac

  CCVL_TYPST_URL="https://github.com/typst/typst/releases/download/v$CCVL_TYPST_VERSION/$CCVL_TYPST_ASSET"
  CCVL_TYPSTYLE_URL="https://github.com/typstyle-rs/typstyle/releases/download/v$CCVL_TYPSTYLE_VERSION/$CCVL_TYPSTYLE_ASSET"
  CCVL_JUST_URL="https://github.com/casey/just/releases/download/$CCVL_JUST_VERSION/$CCVL_JUST_ASSET"
}
