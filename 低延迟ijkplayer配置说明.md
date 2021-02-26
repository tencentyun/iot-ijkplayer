# 低延迟ijkplayer配置说明

1. 码率探测分析数据量

```java
ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", 10 * 1000);
ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize", 10240);
```
   * 注意：__网上很多文章把`analyzeduration`写成了`analyzemaxduration`，实际是以讹传讹，`analyzemaxduration`没有任何作用__

   * analyzeduration，配置探测时长，单位微秒

   * probesize，探测的字节数

   * 这两个配置影响秒开

   * __如果播放器没有倍速追帧策略，probesize过大会影响延迟；加上追帧策略后，<u>播放一段时间后可以消除影响</u>__

-----

2. prepare后自动start，可以加速秒开

  ```java
  ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1);
  ```

-----------------

3. 音视频启动时不做对齐，加速秒开

  ```java
  ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "sync-av-start", 0);
  ```

----------------

4. 关闭缓冲不足时pause，避免低延迟反复缓冲

  ```java
  ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", 0);
  ```
-------------

5. 解码配置

   1. 不同的手机厂家机型，MediaCodec延迟不同，使用MediaCodec解码对延迟的影响不可控；为了达到稳定可靠低延迟的目的，尽量使用软件解码

   2. H.264软解压力不大，H.265软解要看视频规格（分辨率、帧率）和cpu性能

   3. 解码线程数影响解码性能和延迟：多线程解码性能好，但是每增加一个线程，带来一帧的延迟

   4. 策略：

      1. 根据编码格式、分辨率、设备cpu性能等，选择软解或硬解，`mediacodec-avc`和`mediacodec-hevc`可单独配置

      2. 在使用软解时，也要权衡处理性能和延迟的矛盾，__合理设置解码线程数，建议运行时做调整，上限不超过4个线程__

         ```java
         ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_CODEC, "threads", 1);
         ```

-----

6. 追帧策略

   1. 调整实时流判断策略：在`packet-buffering`为0，http/https/rtmp都当做实时流，相关改动在

      ```c
      static int is_realtime(AVFormatContext *s, int packet_buffering)
      ```

   2. 对于实时流，采用系统时钟做主时钟

      ```c
      static int get_master_sync_type(VideoState *is) {
          if (is->realtime)
              return AV_SYNC_EXTERNAL_CLOCK;
          ...
      }
      ```

   3. 采用比较激进的策略调整系统时钟的速度，缓存多时加速播放