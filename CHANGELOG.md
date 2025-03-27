# Changelog

## [1.1.1](https://github.com/rancher/terraform-rancher2-aws/compare/v1.1.0...v1.1.1) (2025-03-27)


### Bug Fixes

* split tests to different runners ([#81](https://github.com/rancher/terraform-rancher2-aws/issues/81)) ([6e320e4](https://github.com/rancher/terraform-rancher2-aws/commit/6e320e4ff58476267cd92ef3f12a6d6cf261135a))
* use deploy path properly ([#83](https://github.com/rancher/terraform-rancher2-aws/issues/83)) ([3671b8d](https://github.com/rancher/terraform-rancher2-aws/commit/3671b8d0ba3741a3e37e578e80b88b910e4edf33))

## [1.1.0](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.5...v1.1.0) (2025-03-27)


### Features

* enable back ends for sub modules ([b62cde1](https://github.com/rancher/terraform-rancher2-aws/commit/b62cde1cc6dea5e673034489d2360fc1c426aec5))

## [1.0.5](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.4...v1.0.5) (2025-03-26)


### Bug Fixes

* copy lock file ([#78](https://github.com/rancher/terraform-rancher2-aws/issues/78)) ([907056b](https://github.com/rancher/terraform-rancher2-aws/commit/907056b2f04254330090191e0aec38f3e7c3eac8))

## [1.0.4](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.3...v1.0.4) (2025-03-26)


### Bug Fixes

* skip initialization when using plugin cache ([#76](https://github.com/rancher/terraform-rancher2-aws/issues/76)) ([9544909](https://github.com/rancher/terraform-rancher2-aws/commit/95449094d2cc030804a9b3622b3575a263ad174b))

## [1.0.3](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.2...v1.0.3) (2025-03-25)


### Bug Fixes

* plugin cache directory ([#74](https://github.com/rancher/terraform-rancher2-aws/issues/74)) ([d5246ab](https://github.com/rancher/terraform-rancher2-aws/commit/d5246aba674165669afbc258f8ab04928f7d7f3e))

## [1.0.2](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.1...v1.0.2) (2025-03-25)


### Bug Fixes

* allow for plugin cache ([#71](https://github.com/rancher/terraform-rancher2-aws/issues/71)) ([299b6b1](https://github.com/rancher/terraform-rancher2-aws/commit/299b6b179f4ceaf417698d867779eb1abb40db1e))

## [1.0.1](https://github.com/rancher/terraform-rancher2-aws/compare/v1.0.0...v1.0.1) (2025-03-24)


### Bug Fixes

* allow module plugin cache ([#69](https://github.com/rancher/terraform-rancher2-aws/issues/69)) ([56cb973](https://github.com/rancher/terraform-rancher2-aws/commit/56cb9739f7bd8be0ec2a92ae2826be49d1453bbc))

## [1.0.0](https://github.com/rancher/terraform-rancher2-aws/compare/v0.3.1...v1.0.0) (2025-03-24)


### ⚠ BREAKING CHANGES

* release version one ([#68](https://github.com/rancher/terraform-rancher2-aws/issues/68))

### Features

* release version one ([#68](https://github.com/rancher/terraform-rancher2-aws/issues/68)) ([836ab00](https://github.com/rancher/terraform-rancher2-aws/commit/836ab00bdb7573fcb5b35a5a67c01b2b6ef1f3f4))


### Bug Fixes

* remove version constraints ([#65](https://github.com/rancher/terraform-rancher2-aws/issues/65)) ([ae1f6d3](https://github.com/rancher/terraform-rancher2-aws/commit/ae1f6d3c4c57fcd32353ccb413893e5b6d471dd0))
* update the prep scripts and module versions ([#67](https://github.com/rancher/terraform-rancher2-aws/issues/67)) ([2fe2369](https://github.com/rancher/terraform-rancher2-aws/commit/2fe23696e18934778e858bd6beeb5925879f19cb))

## [0.3.1](https://github.com/rancher/terraform-rancher2-aws/compare/v0.3.0...v0.3.1) (2025-02-10)


### Bug Fixes

* upgrade versions, fix spacing, integration ([#63](https://github.com/rancher/terraform-rancher2-aws/issues/63)) ([084713e](https://github.com/rancher/terraform-rancher2-aws/commit/084713e68b127479a9071722e49438b967ca4ad2))

## [0.3.0](https://github.com/rancher/terraform-rancher2-aws/compare/v0.2.1...v0.3.0) (2025-02-06)


### Features

* ability to use temporary credentials ([#61](https://github.com/rancher/terraform-rancher2-aws/issues/61)) ([ec063b0](https://github.com/rancher/terraform-rancher2-aws/commit/ec063b0553f56daf6c413f6368312c45f0f8587b))
* Test Downstream Clusters ([#54](https://github.com/rancher/terraform-rancher2-aws/issues/54)) ([402f60d](https://github.com/rancher/terraform-rancher2-aws/commit/402f60d31cd4fbd0bbc3a0b1b505a07ad3f9707f))


### Bug Fixes

* add zone back in ([#58](https://github.com/rancher/terraform-rancher2-aws/issues/58)) ([ec3030d](https://github.com/rancher/terraform-rancher2-aws/commit/ec3030dc2d3cbf43ea264f591c2468cb2429fa44))
* enable ambient credentials ([#59](https://github.com/rancher/terraform-rancher2-aws/issues/59)) ([bec03f6](https://github.com/rancher/terraform-rancher2-aws/commit/bec03f68445de4af883052751905d2c663a275ca))
* increase attempts for certificate validation ([#57](https://github.com/rancher/terraform-rancher2-aws/issues/57)) ([7227927](https://github.com/rancher/terraform-rancher2-aws/commit/72279273d476d2dc196a839986a5270020735281))
* retry client connection lost errors ([#60](https://github.com/rancher/terraform-rancher2-aws/issues/60)) ([dd595fd](https://github.com/rancher/terraform-rancher2-aws/commit/dd595fdb2eafb06cc508347955496e356f897a14))
* set configuration environment variable ([#62](https://github.com/rancher/terraform-rancher2-aws/issues/62)) ([950a237](https://github.com/rancher/terraform-rancher2-aws/commit/950a2378048f1a451d96af600816743941a86fc3))
* trigger workflow with new permissions ([#56](https://github.com/rancher/terraform-rancher2-aws/issues/56)) ([903f378](https://github.com/rancher/terraform-rancher2-aws/commit/903f378683750dadd85e5ee85c64f644f658b1f2))

## [0.2.1](https://github.com/rancher/terraform-rancher2-aws/compare/v0.2.0...v0.2.1) (2025-01-13)


### Bug Fixes

* enable automatic testing and refactor tests ([#51](https://github.com/rancher/terraform-rancher2-aws/issues/51)) ([5f3c4e9](https://github.com/rancher/terraform-rancher2-aws/commit/5f3c4e9825306248fae297495b3341b39ffb6911))
* update release please action ([#53](https://github.com/rancher/terraform-rancher2-aws/issues/53)) ([e520b5f](https://github.com/rancher/terraform-rancher2-aws/commit/e520b5fc6e1874611c140b6ff59df58fbc2b3464))

## [0.2.0](https://github.com/rancher/terraform-rancher2-aws/compare/v0.1.0...v0.2.0) (2024-11-13)


### Features

* Basic tests pass ([#13](https://github.com/rancher/terraform-rancher2-aws/issues/13)) ([89b2042](https://github.com/rancher/terraform-rancher2-aws/commit/89b2042a26d910b525cbb68213d3da2e07aaf18b))
* enable node configuration ([#21](https://github.com/rancher/terraform-rancher2-aws/issues/21)) ([3c72409](https://github.com/rancher/terraform-rancher2-aws/commit/3c724091fe8be1c6dd71d62e5bb2a0dbdd367406))


### Bug Fixes

* add a check for the certificate ([#24](https://github.com/rancher/terraform-rancher2-aws/issues/24)) ([0102c75](https://github.com/rancher/terraform-rancher2-aws/commit/0102c75412840c7b3fbbfdc8256ba5696f487b07))
* add log to troubleshoot certificate issue ([#45](https://github.com/rancher/terraform-rancher2-aws/issues/45)) ([ff1dfd9](https://github.com/rancher/terraform-rancher2-aws/commit/ff1dfd9b692e38474db8d25e9d50806ce0877d27))
* add private address to hosts file in example ([#39](https://github.com/rancher/terraform-rancher2-aws/issues/39)) ([a3da708](https://github.com/rancher/terraform-rancher2-aws/commit/a3da7087fcab119e2d8ac24fdca9a0ceafc75a46))
* add rotate certificates to example ([#37](https://github.com/rancher/terraform-rancher2-aws/issues/37)) ([7d068ac](https://github.com/rancher/terraform-rancher2-aws/commit/7d068ac7ddec22f0e2a21f22eb80e2476701a1fb))
* append certificate chain to the certificate ([#49](https://github.com/rancher/terraform-rancher2-aws/issues/49)) ([676ce61](https://github.com/rancher/terraform-rancher2-aws/commit/676ce61716fda2bd09bb54bd9164b830f31b7b90))
* check certificate authorities ([#42](https://github.com/rancher/terraform-rancher2-aws/issues/42)) ([9740017](https://github.com/rancher/terraform-rancher2-aws/commit/97400172e063ac18c3c4c937781b92a38232a7a1))
* check out what is going on with ping ([#44](https://github.com/rancher/terraform-rancher2-aws/issues/44)) ([75bfed0](https://github.com/rancher/terraform-rancher2-aws/commit/75bfed0dc338ae349b7e578cdcce8b632a18c31f))
* create cert manager name space if necessary ([#38](https://github.com/rancher/terraform-rancher2-aws/issues/38)) ([d152d67](https://github.com/rancher/terraform-rancher2-aws/commit/d152d67c949c94891f1b85c868e35c1953646680))
* dependency issues with certificate resources ([#43](https://github.com/rancher/terraform-rancher2-aws/issues/43)) ([50cf1fa](https://github.com/rancher/terraform-rancher2-aws/commit/50cf1fa8bbf6453817efb978d1c6c62c5b5d0398))
* example with cert manager configured ([#30](https://github.com/rancher/terraform-rancher2-aws/issues/30)) ([23988b9](https://github.com/rancher/terraform-rancher2-aws/commit/23988b9300aacfe6cd86d24080ace76d689a2ed0))
* filter access denied messages ([#40](https://github.com/rancher/terraform-rancher2-aws/issues/40)) ([0588255](https://github.com/rancher/terraform-rancher2-aws/commit/0588255238d948b794776a01a3a6bdefa817c315))
* ignore access denied issues from leftovers ([#20](https://github.com/rancher/terraform-rancher2-aws/issues/20)) ([4d6430b](https://github.com/rancher/terraform-rancher2-aws/commit/4d6430babe28f6d66edbd9fea8ab1e591773611c))
* ignore errors on git leaks ([#22](https://github.com/rancher/terraform-rancher2-aws/issues/22)) ([f00980c](https://github.com/rancher/terraform-rancher2-aws/commit/f00980c7e000aa84d2d6908f57f1d44657efcafb))
* install all intermediate certificates ([#48](https://github.com/rancher/terraform-rancher2-aws/issues/48)) ([62f33ad](https://github.com/rancher/terraform-rancher2-aws/commit/62f33adb1b71c7a80dd2d8cdb8523799fac7b058))
* install the intermediate certificate ([#47](https://github.com/rancher/terraform-rancher2-aws/issues/47)) ([a612adb](https://github.com/rancher/terraform-rancher2-aws/commit/a612adb1fa5cd8a9a52f1febb907b7ff0ed076ae))
* issue body format ([#34](https://github.com/rancher/terraform-rancher2-aws/issues/34)) ([c97038a](https://github.com/rancher/terraform-rancher2-aws/commit/c97038a1062e44284d281ab7a405965f6ff99aa2))
* put body in quotes ([#35](https://github.com/rancher/terraform-rancher2-aws/issues/35)) ([e27d266](https://github.com/rancher/terraform-rancher2-aws/commit/e27d2660717c3c000e31e593f0cb4c7d33f290a6))
* quote the parameters ([#36](https://github.com/rancher/terraform-rancher2-aws/issues/36)) ([4df2f7c](https://github.com/rancher/terraform-rancher2-aws/commit/4df2f7c25a8eafbb3781e20fdead88e56b3809f7))
* release test fails properly ([#18](https://github.com/rancher/terraform-rancher2-aws/issues/18)) ([a889fe0](https://github.com/rancher/terraform-rancher2-aws/commit/a889fe09b8e2c969220173d7bb024d7e688c2ec1))
* remove call to get pods ([#27](https://github.com/rancher/terraform-rancher2-aws/issues/27)) ([f54935e](https://github.com/rancher/terraform-rancher2-aws/commit/f54935eb6a1b2e66faed5879d7f47ad93605817b))
* remove workspace from example variables ([#15](https://github.com/rancher/terraform-rancher2-aws/issues/15)) ([5c61a4a](https://github.com/rancher/terraform-rancher2-aws/commit/5c61a4a1d2902b7f0f0ad1c2091a70f0b3899045))
* resolve dependency ([#26](https://github.com/rancher/terraform-rancher2-aws/issues/26)) ([2b04297](https://github.com/rancher/terraform-rancher2-aws/commit/2b042975dd521354d4860cca6cfe0621c589e63f))
* resolve issues checking certificate ([#32](https://github.com/rancher/terraform-rancher2-aws/issues/32)) ([79bed01](https://github.com/rancher/terraform-rancher2-aws/commit/79bed01dc8d03de59ca4bda0e094120ffe0459f2))
* resolve workflow restriction issues ([#31](https://github.com/rancher/terraform-rancher2-aws/issues/31)) ([86ac470](https://github.com/rancher/terraform-rancher2-aws/commit/86ac470552e952c360740439845a0a8385a7c8f1))
* resolve workflow spacing issues ([#33](https://github.com/rancher/terraform-rancher2-aws/issues/33)) ([d16f9c7](https://github.com/rancher/terraform-rancher2-aws/commit/d16f9c7f279abb552eb6bc54eb0be4298835ba22))
* try changing the commands a bit ([#46](https://github.com/rancher/terraform-rancher2-aws/issues/46)) ([60fe407](https://github.com/rancher/terraform-rancher2-aws/commit/60fe407924b7860430c810f6a769156d3e6cc83a))
* try waiting for jobs to complete ([#25](https://github.com/rancher/terraform-rancher2-aws/issues/25)) ([370335d](https://github.com/rancher/terraform-rancher2-aws/commit/370335d284f5e289d7eaa8b61ccd0427f5d7f8ca))
* update requirements ([#17](https://github.com/rancher/terraform-rancher2-aws/issues/17)) ([d17b659](https://github.com/rancher/terraform-rancher2-aws/commit/d17b65910ae4631d33acfa9c9f73e414b53dc35e))
* update the run test documentation ([#19](https://github.com/rancher/terraform-rancher2-aws/issues/19)) ([bb14976](https://github.com/rancher/terraform-rancher2-aws/commit/bb1497659c23fe35190f7fbac0a863bdc336b39a))
* upgrade dependencies ([#16](https://github.com/rancher/terraform-rancher2-aws/issues/16)) ([448cb71](https://github.com/rancher/terraform-rancher2-aws/commit/448cb71fcabd0cf1b9b776573065e98fa628e01c))
* use a real certificate ([#41](https://github.com/rancher/terraform-rancher2-aws/issues/41)) ([eb61ef6](https://github.com/rancher/terraform-rancher2-aws/commit/eb61ef6a61dbf80f91bd6e28745ca048b0d40be6))
* use real certificates ([#23](https://github.com/rancher/terraform-rancher2-aws/issues/23)) ([f2dd38a](https://github.com/rancher/terraform-rancher2-aws/commit/f2dd38a322a4dba7981e429637bae2195a4730a9))

## 0.1.0 (2024-06-25)


### Features

* implement high availability cluster ([#2](https://github.com/rancher/terraform-rancher2-aws/issues/2)) ([4b0cd8f](https://github.com/rancher/terraform-rancher2-aws/commit/4b0cd8fc8958d55baaa00a39d9aeed904985fd62))


### Bug Fixes

* bump integrations/github from 6.2.1 to 6.2.2 ([#3](https://github.com/rancher/terraform-rancher2-aws/issues/3)) ([69b6b90](https://github.com/rancher/terraform-rancher2-aws/commit/69b6b900c47fa43a7acd7c06aad0cbfe160d665a))
* use new release-please location ([#5](https://github.com/rancher/terraform-rancher2-aws/issues/5)) ([731ec1b](https://github.com/rancher/terraform-rancher2-aws/commit/731ec1b5d2e8a1254b8ff22735fbe5c8542219f6))
