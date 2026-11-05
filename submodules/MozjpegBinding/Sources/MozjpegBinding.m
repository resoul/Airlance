#import <MozjpegBinding/MozjpegBinding.h>

#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>

#include <mozjpeg/jpeglib.h>

typedef struct {
    struct jpeg_error_mgr base;
    jmp_buf jump;
} EncoderErrors;

static void leaveOnError(j_common_ptr info) {
    EncoderErrors *errors = (EncoderErrors *)info->err;
    longjmp(errors->jump, 1);
}

static void ignoreMessage(j_common_ptr info) {
}

static uint8_t *copyPixels(CGImageRef image, size_t width, size_t height, size_t *bytesPerRow) {
    *bytesPerRow = width * 4;
    uint8_t *pixels = malloc(*bytesPerRow * height);
    if (pixels == NULL) {
        return NULL;
    }

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(
        pixels,
        width,
        height,
        8,
        *bytesPerRow,
        space,
        kCGBitmapByteOrder32Big | (CGBitmapInfo)kCGImageAlphaNoneSkipLast
    );
    CGColorSpaceRelease(space);
    if (context == NULL) {
        free(pixels);

        return NULL;
    }

    CGRect bounds = CGRectMake(0, 0, width, height);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, bounds);
    CGContextDrawImage(context, bounds, image);
    CGContextRelease(context);

    return pixels;
}

NSData *MozjpegEncode(CGImageRef image, int quality) {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    if (width == 0 || height == 0 || width > JPEG_MAX_DIMENSION || height > JPEG_MAX_DIMENSION) {
        return nil;
    }

    size_t bytesPerRow = 0;
    uint8_t * volatile pixels = copyPixels(image, width, height, &bytesPerRow);
    if (pixels == NULL) {
        return nil;
    }

    struct jpeg_compress_struct info;
    EncoderErrors errors;
    unsigned char * volatile output = NULL;
    unsigned long outputSize = 0;

    info.err = jpeg_std_error(&errors.base);
    errors.base.error_exit = leaveOnError;
    errors.base.output_message = ignoreMessage;
    if (setjmp(errors.jump) != 0) {
        jpeg_destroy_compress(&info);
        free(output);
        free(pixels);

        return nil;
    }

    jpeg_create_compress(&info);
    jpeg_mem_dest(&info, (unsigned char **)&output, &outputSize);
    info.image_width = (JDIMENSION)width;
    info.image_height = (JDIMENSION)height;
    info.input_components = 4;
    info.in_color_space = JCS_EXT_RGBX;
    jpeg_set_defaults(&info);
    jpeg_set_quality(&info, quality, TRUE);
    jpeg_start_compress(&info, TRUE);
    while (info.next_scanline < info.image_height) {
        JSAMPROW row = pixels + info.next_scanline * bytesPerRow;
        jpeg_write_scanlines(&info, &row, 1);
    }
    jpeg_finish_compress(&info);

    NSData *result = [NSData dataWithBytes:output length:outputSize];
    jpeg_destroy_compress(&info);
    free(output);
    free(pixels);

    return result;
}
