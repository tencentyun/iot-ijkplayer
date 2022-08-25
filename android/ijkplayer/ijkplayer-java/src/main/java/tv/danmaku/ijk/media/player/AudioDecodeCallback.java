package tv.danmaku.ijk.media.player;

public interface AudioDecodeCallback {
    void audioDecodePcmDataHandle(byte[] data, int len);
}
