#include <stdint.h>

typedef struct {
    int64_t first;
    int64_t second;
    int64_t length;
} ProbeResult;

int32_t scalar_first(const unsigned char *data, int32_t length) {
    return length > 0 ? data[0] : -1;
}

ProbeResult struct_bytes(const unsigned char *data, int32_t length) {
    ProbeResult result = {data[0], data[1], length};
    return result;
}
