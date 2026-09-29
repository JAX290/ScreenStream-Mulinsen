package info.dvkr.screenstream.common

public object DeploymentEndpoints {
    public const val ROOT_DOMAIN: String = "mulinsen.win"
    public const val INGEST_HOST: String = "ingest.mulinsen.win"
    public const val VIEW_BASE_URL: String = "http://api.mulinsen.win"
    public const val API_BASE_URL: String = "http://api.mulinsen.win"
    public const val APK_DOWNLOAD_URL: String = "http://view.mulinsen.win/apk1"
    public const val DEFAULT_DEVICE_PATH: String = "phone/nova6"
    public const val DEFAULT_RTSP_URL: String = "rtsps://$INGEST_HOST:8322/$DEFAULT_DEVICE_PATH"
}
