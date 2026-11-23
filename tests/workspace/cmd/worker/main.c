#include "shared.h"
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc != 2) return 1;
    printf("worker %s %s\n", message(), argv[1]);
    return 0;
}
