#import <FFmpegBinding/FFmpegBinding.h>

#include <libavformat/avformat.h>
#include <libavutil/dict.h>

static BOOL copyPackets(
    AVFormatContext *input,
    AVFormatContext *output,
    AVStream *source,
    AVStream *target,
    double maxDuration
) {
    AVPacket *packet = av_packet_alloc();
    if (packet == NULL) {
        return NO;
    }

    int64_t start = source->start_time == AV_NOPTS_VALUE ? 0 : source->start_time;
    int64_t limit = start + av_rescale_q((int64_t)(maxDuration * AV_TIME_BASE), AV_TIME_BASE_Q, source->time_base);
    BOOL succeeded = YES;
    int written = 0;
    while (succeeded && av_read_frame(input, packet) >= 0) {
        BOOL keeps = packet->stream_index == source->index && packet->pts != AV_NOPTS_VALUE && packet->pts < limit;
        if (keeps) {
            packet->stream_index = target->index;
            av_packet_rescale_ts(packet, source->time_base, target->time_base);
            packet->pos = -1;
            succeeded = av_interleaved_write_frame(output, packet) >= 0;
            written += 1;
        }
        av_packet_unref(packet);
    }
    av_packet_free(&packet);

    return succeeded && written > 0;
}

static BOOL writeOutput(AVFormatContext *input, AVStream *source, const char *path, double maxDuration) {
    AVFormatContext *output = NULL;
    if (avformat_alloc_output_context2(&output, NULL, "mp4", path) < 0 || output == NULL) {
        return NO;
    }

    BOOL succeeded = NO;
    AVStream *target = avformat_new_stream(output, NULL);
    if (target != NULL && avcodec_parameters_copy(target->codecpar, source->codecpar) >= 0
        && avio_open(&output->pb, path, AVIO_FLAG_WRITE) >= 0) {
        target->codecpar->codec_tag = 0;
        target->time_base = source->time_base;
        AVDictionary *options = NULL;
        av_dict_set(&options, "movflags", "+faststart", 0);
        if (avformat_write_header(output, &options) >= 0) {
            succeeded = copyPackets(input, output, source, target, maxDuration);
            succeeded = av_write_trailer(output) >= 0 && succeeded;
        }
        av_dict_free(&options);
        avio_closep(&output->pb);
    }
    avformat_free_context(output);

    return succeeded;
}

BOOL FFmpegCopyVideoTrack(NSString *inputPath, NSString *outputPath, double maxDuration) {
    AVFormatContext *input = NULL;
    if (avformat_open_input(&input, inputPath.fileSystemRepresentation, NULL, NULL) < 0) {
        return NO;
    }

    BOOL succeeded = NO;
    if (avformat_find_stream_info(input, NULL) >= 0) {
        int index = av_find_best_stream(input, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
        if (index >= 0) {
            AVStream *source = input->streams[index];
            succeeded = writeOutput(input, source, outputPath.fileSystemRepresentation, maxDuration);
        }
    }
    avformat_close_input(&input);
    if (!succeeded) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:NULL];
    }

    return succeeded;
}
