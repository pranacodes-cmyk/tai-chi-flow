// Install-time asset pack for the coach voice clips (filled only by the store release workflow).
// Files sit at flutter_assets/assets/voice/<key>.m4a, the same path Flutter's asset loader
// requests, so the app reads them unchanged once Play installs the pack with the app.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("voice_pack")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}
